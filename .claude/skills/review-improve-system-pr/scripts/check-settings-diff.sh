#!/usr/bin/env bash
# check-settings-diff.sh — Decide whether a change to .claude/settings.json stays
# inside the weekly routine's auto-apply boundary: purely additive entries in
# `permissions.allow`, and nothing else.
#
# Usage: check-settings-diff.sh <base.json> <head.json>
# Pure local check: reads the two files, never touches the network or the repo.
#
# Boundary (all must hold):
#   - everything outside `permissions.allow` (deny, ask, hooks, env, ...) is identical
#   - no existing allow entry is removed
#   - every added entry is either `mcp__<server>__<tool>` or a scoped `Bash(<cmd>)`
#     whose argument does not start with `*` and has no `;` `|` `&` backtick `$(`
#     (so the routine can't land `Bash(*)`, a bare `Bash`, or a chained command)
#   - second pass (below): an entry that is structurally scoped can still be dangerous,
#     so additions are also refused when they grant a high-power command, a wildcard
#     over a command multiplexer, a path outside the repo / ~/.claude, an interpreter
#     without a concrete repo script, a credential location (~/.ssh, secrets, ...), or
#     an MCP tool whose name says it writes or sends (or a whole-server `mcp__<server>`).
#     This is a fail-closed denylist safety net, not a proof of safety: a refusal just
#     means "a human reviews this entry", and a pass still gets a human diff review.
#
# Exit codes:
#   0 — boundary holds; prints one `ADDED: <entry>` line per new entry
#   1 — boundary broken or input unreadable; prints one `REASON: <why>` line
set -uo pipefail

fail() {
  echo "REASON: $1"
  exit 1
}

[ $# -eq 2 ] || fail "usage: check-settings-diff.sh <base.json> <head.json>"
BASE=$1
HEAD=$2

for f in "$BASE" "$HEAD"; do
  jq -e . "$f" > /dev/null 2>&1 || fail "not valid JSON: $f"
  jq -e '(.permissions.allow // []) | type == "array" and all(type == "string")' "$f" > /dev/null 2>&1 \
    || fail "permissions.allow is not an array of strings: $f"
done

[ "$(jq -S 'del(.permissions.allow)' "$BASE")" = "$(jq -S 'del(.permissions.allow)' "$HEAD")" ] \
  || fail "changes outside permissions.allow"

REMOVED=$(jq -r --slurpfile b "$BASE" '($b[0].permissions.allow // []) - (.permissions.allow // []) | .[]' "$HEAD")
[ -z "$REMOVED" ] || fail "removes allow entries: $(echo "$REMOVED" | paste -sd, -)"

# Control characters (newline, tab, DEL, ...) have no business in a rule and would be
# split across lines by the line-oriented checks below.
CTRL=$(jq -r --slurpfile b "$BASE" '((.permissions.allow // []) - ($b[0].permissions.allow // []))[] | select(explode | any(. < 32 or . == 127))' "$HEAD")
[ -z "$CTRL" ] || fail "added allow entry contains control characters"

ADDED=$(jq -r --slurpfile b "$BASE" '(.permissions.allow // []) - ($b[0].permissions.allow // []) | .[]' "$HEAD")

while IFS= read -r entry; do
  [ -z "$entry" ] && continue
  if [[ "$entry" =~ ^(Bash\([^*\)][^\)]*\)|mcp__[A-Za-z0-9_-]+)$ ]] \
    && [[ "$entry" != *[\;\|\&\`]* ]] && [[ "$entry" != *'$('* ]]; then
    continue
  fi
  fail "added allow entry outside the boundary: $entry"
done <<< "$ADDED"

# ---- Second pass: structurally scoped is not the same as safe ----------------------
#
# Bash rules match by string prefix, so an entry is judged on its literal text up to the
# first `*` (call it L). It is refused when L names a dangerous command (L starts with it
# at a word boundary) or, if the entry ends in a glob, when a dangerous command starts
# with L (e.g. `gh pr m*` can match `gh pr merge`; `gh *` and `sud*` match everything
# dangerous under them). Interpreters are allowed only against a concrete script with an
# extension under this repo or ~/.claude, with no `..` segments.

DANGER_CMDS=(
  # delete / overwrite / permission changes
  rm rmdir shred truncate dd mv cp ln install tee chmod chown chgrp mkfs
  # privilege escalation, wrappers that run another command, remote shells and fetchers
  sudo su doas run0 pkexec env xargs nice ionice chroot flock strace gdb watch script
  unshare nsenter systemd-run timeout nohup setsid time command builtin source busybox
  eval exec ssh scp sftp rsync curl wget nc ncat socat
  # commands whose own flags run or delete things (-exec, -delete, -i, system(), ...)
  find awk gawk sed make just npx uvx pipx
  # processes, services, machine state, disks, network
  kill pkill killall systemctl loginctl machinectl reboot poweroff shutdown halt
  mount umount crontab passwd useradd usermod userdel visudo iptables nft modprobe insmod
  rmmod losetup wipefs parted fdisk sfdisk cryptsetup mkswap swapon swapoff
  # NixOS / Nix state changes and arbitrary-code launchers
  nh nixos-rebuild nix-collect-garbage nix-shell nix-env nix-channel home-manager sops
  'nix run' 'nix shell' 'nix develop' 'nix profile' 'nix copy' 'nix store' 'nix upgrade-nix'
  'nix registry' 'nix repl' 'nix daemon' 'nix bundle' 'nix fmt' 'nix key'
  'nix flake update' 'nix flake lock' 'nix flake init' 'nix flake new' 'nix flake archive'
  'nix flake prefetch' 'nix flake clone'
  # package managers / container runtimes (fail closed: review by hand)
  npm pip pip3 cargo go gem uv poetry docker podman kubectl brew apt apt-get dpkg pacman
  yum dnf snap
  'flatpak install' 'flatpak uninstall' 'flatpak update' 'flatpak run' 'flatpak override'
  'flatpak remove' 'flatpak repair' 'flatpak remote-add' 'flatpak remote-delete'
  'flatpak remote-modify' 'flatpak config' 'flatpak kill' 'flatpak mask' 'flatpak pin'
  # git: anything that writes the repo, history, config or the remote
  'git push' 'git reset' 'git clean' 'git checkout' 'git rebase' 'git commit' 'git add'
  'git rm' 'git mv' 'git restore' 'git switch' 'git merge' 'git pull' 'git cherry-pick'
  'git revert' 'git am' 'git apply' 'git config' 'git branch' 'git tag' 'git stash'
  'git update-ref' 'git filter-branch' 'git worktree' 'git remote' 'git submodule'
  'git init' 'git clone' 'git gc' 'git prune' 'git reflog' 'git bisect' 'git send-email'
  'git daemon'
  # gh: anything that writes to GitHub, reads arbitrary API paths, or touches auth/secrets
  'gh api' 'gh auth' 'gh repo' 'gh secret' 'gh variable' 'gh workflow' 'gh release'
  'gh ssh-key' 'gh gpg-key' 'gh codespace' 'gh extension' 'gh alias' 'gh config' 'gh label'
  'gh cache' 'gh gist' 'gh org' 'gh ruleset' 'gh project'
  'gh pr merge' 'gh pr close' 'gh pr create' 'gh pr edit' 'gh pr review' 'gh pr comment'
  'gh pr ready' 'gh pr reopen' 'gh pr checkout' 'gh pr lock' 'gh pr unlock'
  'gh pr update-branch'
  'gh issue create' 'gh issue close' 'gh issue edit' 'gh issue delete' 'gh issue comment'
  'gh issue reopen' 'gh issue transfer' 'gh issue lock' 'gh issue unlock' 'gh issue pin'
  'gh issue unpin' 'gh issue develop'
  'gh run rerun' 'gh run cancel' 'gh run delete'
)
# Never allowed as an interpreter-without-script, only against a concrete safe script.
INTERP_CMDS=(bash sh zsh fish dash python python3 perl ruby node)
INTERP_RE='(bash|sh|zsh|fish|dash|python[0-9.]*|perl|ruby|node)'
SAFE_ROOT='(/home/bosko/NixOS/|/home/bosko/\.claude/|~/\.claude/|\.claude/)'
# Read-only commands can still exfiltrate: refuse any rule that names a credential location.
SENSITIVE_RE='(\.ssh|\.gnupg|\.aws|\.netrc|\.npmrc|\.pgpass|id_(rsa|ed25519|ecdsa|dsa)|age-key|keys\.txt|/etc/(shadow|gshadow|sudoers|ssh)|/run/secrets|/proc/|credentials|\.env($|[^A-Za-z]))'

# MCP tool-name words that mean "writes, sends, deletes or acts" (matched after splitting
# camelCase / snake_case / kebab-case into words).
MCP_WRITE='send|create|delete|remove|update|set|write|post|put|patch|modify|edit|add|insert|upload|publish|push|merge|close|approve|reject|authorize|deauthorize|expire|rotate|invite|resend|restore|suspend|rename|move|archive|trash|execute|exec|run|invoke|call|deploy|start|stop|restart|kill|drop|reset|revoke|grant|share|forward|reply|draft|label|mark|commit|apply|accept|cancel|confirm|submit|transfer|import|enable|disable|install|uninstall|login|logout|schedule|book|pay|order|purchase|click|type|fill|navigate|evaluate|batch'
MCP_WRITE_PREFIX='send|create|delete|remove|write|publish|merge|update|upload'

# first_word S — first token of S, cut at whitespace, `*` or `:` (leading blanks/colons dropped)
first_word() {
  local s=$1
  s=${s#"${s%%[![:space:]:]*}"}
  printf '%s' "${s%%[[:space:]*:]*}"
}

# rest_after S — S with its first token (and the blanks/colons after it) removed
rest_after() {
  local s=$1 w
  s=${s#"${s%%[![:space:]:]*}"}
  w=${s%%[[:space:]*:]*}
  s=${s#"$w"}
  printf '%s' "${s#"${s%%[![:space:]:]*}"}"
}

# safe_script P — P is a concrete file with an extension under a trusted root, no `..` segment
safe_script() {
  local p=$1
  [[ "$p" =~ (^|/)\.\.(/|$) ]] && return 1
  [[ "$p" =~ ^${SAFE_ROOT}([A-Za-z0-9._-]+/)*[A-Za-z0-9_-][A-Za-z0-9._-]*\.[A-Za-z0-9]+$ ]]
}

# overlaps L GLOB LIST... — does literal prefix L (GLOB=1 if the entry ends in a glob) name,
# or (with a glob) match the start of, any command in LIST?
overlaps() {
  local l=$1 glob=$2 d
  shift 2
  for d in "$@"; do
    if [[ "$l" == "$d" || "$l" == "$d "* ]]; then return 0; fi
    if [ "$glob" = 1 ] && [[ "$d" == "$l"* ]]; then return 0; fi
  done
  return 1
}

# check_mcp ENTRY — prints a reason and returns 1 when the MCP entry is too broad or can write
check_mcp() {
  local rest tool norm
  rest=${1#mcp__}
  [[ "$rest" == *__* ]] || { echo "whole-server MCP entry grants every tool of that server"; return 1; }
  tool=${rest##*__}
  [ -n "$tool" ] || { echo "MCP entry names no tool"; return 1; }
  norm=$(sed -E 's/([a-z0-9])([A-Z])/\1_\2/g; s/-/_/g' <<< "$tool" | tr '[:upper:]' '[:lower:]')
  if [[ "_${norm}_" =~ _(${MCP_WRITE})_ ]] || [[ "$norm" =~ ^(${MCP_WRITE_PREFIX})[a-z] ]]; then
    echo "MCP tool name suggests it writes, sends or deletes"
    return 1
  fi
}

# check_bash ENTRY — prints a reason and returns 1 when the Bash entry is too broad or high-power
check_bash() {
  local entry=$1 arg norm head l glob=0 word2
  if [[ "$entry" == *[\<\>\$]* ]]; then
    echo "redirection or shell expansion in a rule"
    return 1
  fi
  if [[ "$entry" =~ $SENSITIVE_RE ]]; then
    echo "mentions a credential / secret location"
    return 1
  fi
  arg=${entry#Bash(}
  arg=${arg%)}
  arg=${arg#"${arg%%[![:space:]:]*}"}              # drop leading whitespace and colons
  if [ -z "$arg" ] || [[ "$arg" == \** ]]; then
    echo "wildcard (or empty) command head"
    return 1
  fi
  head=$(first_word "$arg")
  if ! [[ "$head" =~ ^[A-Za-z0-9._/~+-]+$ ]]; then
    echo "unusual command head (quotes, '=', backslash, braces, ...)"
    return 1
  fi
  if [ "${#head}" -lt 2 ]; then
    echo "command head too short to be scoped"
    return 1
  fi
  if [[ "$head" == */* || "$head" == "~"* || "$head" == .* ]]; then
    safe_script "$head" || {
      echo "path outside the repo / ~/.claude, containing '..', or not a concrete script file"
      return 1
    }
  fi
  # Literal text up to the first `*`, with `-C/-c/-R/--repo <arg>` dropped so
  # `git -C <repo> push` is read as `git push`; a legacy trailing `:` is dropped too.
  norm=$(sed -E 's/[[:space:]]+(-C|-c|-R|--repo)[[:space:]]+[^[:space:]]+//g' <<< "$arg")
  l=${norm%%\**}
  [ "$l" != "$norm" ] && glob=1
  l=${l%:}
  if [ "$glob" = 1 ] && [ -z "$l" ]; then
    echo "wildcard command head"
    return 1
  fi
  if overlaps "$l" "$glob" "${DANGER_CMDS[@]}" || [[ "$l" == mkfs* ]]; then
    echo "grants (or can match) a high-power command"
    return 1
  fi
  if overlaps "$l" "$glob" "${INTERP_CMDS[@]}"; then
    if [[ "$head" =~ ^${INTERP_RE}$ ]]; then
      word2=$(first_word "$(rest_after "$arg")")
      safe_script "$word2" && return 0
    fi
    echo "interpreter without a concrete script under the repo or ~/.claude"
    return 1
  fi
  # No separate multiplexer rule is needed: `git *`, `gh pr *`, `nix flake *`, `gh pr m*`
  # all have a dangerous command in DANGER_CMDS that starts with their literal prefix.
  return 0
}

while IFS= read -r entry; do
  [ -z "$entry" ] && continue
  if [[ "$entry" == mcp__* ]]; then
    why=$(check_mcp "$entry") || fail "added allow entry is too broad or can act on the world: $entry ($why)"
  else
    why=$(check_bash "$entry") || fail "added allow entry is too broad or grants a high-power command: $entry ($why)"
  fi
done <<< "$ADDED"

while IFS= read -r entry; do
  [ -z "$entry" ] && continue
  echo "ADDED: $entry"
done <<< "$ADDED"
exit 0
