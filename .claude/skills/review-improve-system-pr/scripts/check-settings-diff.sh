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
#   - DEFAULT-DENY second pass (below): an added entry passes ONLY if it is an exact-shape
#     match for a short read-only form. Anything not recognised is refused, so a command
#     nobody thought of (python3.13, nix-build, niri, ...) cannot slip through a denylist.
#     A refusal means "a human reviews this entry"; a pass still gets a human diff review.
#
# What passes (see the *_RE variables below for the exact shapes):
#   Bash:  read-only `git` subcommands (status log diff show rev-parse ls-files describe
#          blame shortlog, fetch), optionally `-C <repo>`, with a small fixed flag set;
#          `gh` view/list/checks/status/diff/watch subcommands; `nix eval` / `nix flake
#          metadata|check|show` / `nix-store -q`; metadata-only inspectors (ls wc stat df du
#          uname which lsblk journalctl ...); `systemctl status|is-active|...`;
#          `flatpak remote-info|list|info|remotes`; and concrete `.claude/` script files
#          (optionally run via `bash`).
#   MCP:   `mcp__<server>__<tool>` whose tool name starts with a read verb and contains no
#          write verb (plus the two read-only nixos tools); never a whole-server entry.
# Canonical form is required: single spaces, no leading/trailing space, characters limited
# to [A-Za-z0-9 ._/~*-], no `..`, and `*` only as the very last character (` *` or `*`).
# Global flags before a subcommand (`git --no-pager push`, `nix --extra-... run`) and every
# other shape fall outside the allowlist and are refused.
#
# Residual risks the checker cannot see (a Bash allow rule is a string prefix, so what
# follows the `*` is unconstrained at run time): `git log|diff|show *` can be invoked with
# `--output=<file>`; `git fetch*` with `--upload-pack`; `nix eval *` with `--impure`;
# and a script entry runs whatever that script contains — the PR file guardrail still lets
# a PR edit `scripts/`, so edited scripts behind existing allow entries need a human look.
#
# Env: REVIEW_SAFE_HOME (default /home/bosko) is the home directory whose NixOS checkout
# and ~/.claude script paths are trusted (the real settings.json entries use absolute paths).
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
# split across lines by the line-oriented checks below. Non-ASCII is refused later by the
# character allowlist.
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

# ---- Second pass: default-deny allowlist ------------------------------------------------

CHARS_RE='^[A-Za-z0-9 ._/~*-]+$'
SAFE_HOME=${REVIEW_SAFE_HOME:-/home/bosko}
[[ "$SAFE_HOME" =~ ^/[A-Za-z0-9._/-]+$ ]] || fail "REVIEW_SAFE_HOME is not a plain absolute path: $SAFE_HOME"
H=${SAFE_HOME//./\\.}

# Concrete script file under a trusted .claude/ tree; `bash` is the only interpreter allowed.
SCRIPT_RE="^(bash )?(${H}/NixOS/\.claude/|${H}/\.claude/|~/\.claude/|\.claude/)(skills/[A-Za-z0-9_-]+/scripts/|skills/lib/|lib/)[A-Za-z0-9_-][A-Za-z0-9._-]*\.(sh|py)$"
GIT_FLAGS='(--stat|--oneline|--name-only|--name-status|--cached|--staged|--short|--porcelain|--graph|--decorate|--all|--no-color|--shortstat|--numstat|-p|-n|-[0-9]+|HEAD)'
GIT_RE="^git( -C ${H}/NixOS)? (status|log|diff|show|rev-parse|ls-files|describe|blame|shortlog)( ${GIT_FLAGS})*$"
GIT_FETCH_RE="^git( -C ${H}/NixOS)? fetch$"
GH_RE='^gh (pr (view|list|checks|status|diff)|run (view|list|watch)|issue (view|list|status)|repo view|workflow (view|list))$'
NIX_RE='^(nix (eval|flake (metadata|check|show))|nix-store -q)$'
INSPECT_RE='^(ls|wc|stat|df|du|uname|which|lsblk|lsusb|lspci|lscpu|uptime|free|whoami|id|pwd|journalctl)( -[A-Za-z]{1,6})*$'
SYSTEMCTL_RE='^systemctl (status|is-active|is-enabled|is-failed|list-units|list-unit-files|list-timers)$'
FLATPAK_RE='^flatpak (remote-info|list|info|remotes)$'

# Read-only commands can still exfiltrate: refuse any rule that names a credential location.
SENSITIVE_RE='(\.ssh|\.gnupg|\.aws|\.netrc|\.npmrc|\.pgpass|\.git-credentials|\.docker|\.kube|\.config/(gh|sops|rclone|chromium|google-chrome)|hosts\.yml|keyring|\.password-store|\.mozilla|\.bash_history|id_(rsa|ed25519|ecdsa|dsa)|age-key|keys\.txt|\.pem|\.key|\.p12|\.kdbx|/etc/(shadow|gshadow|sudoers|ssh|wireguard)|/run/secrets|/proc/|credentials|\.env($|[^A-Za-z]))'

MCP_READ_RE='^(get|list|search|read|view|fetch|query|find|describe|status|ls)'
# Write / act verbs: matched as whole words anywhere in the tool name ...
MCP_WRITE_WORDS='send|create|delete|remove|update|set|write|post|put|patch|modify|edit|add|insert|upload|publish|push|merge|close|approve|reject|authorize|deauthorize|expire|rotate|invite|resend|restore|suspend|rename|move|archive|trash|execute|exec|run|invoke|call|deploy|start|stop|restart|kill|drop|reset|revoke|grant|share|forward|reply|comment|message|save|notify|replace|assign|clear|flush|sync|tag|pin|star|follow|like|vote|subscribe|unsubscribe|join|leave|lock|unlock|trigger|dispatch|broadcast|mention|react|respond|draft|label|mark|commit|apply|accept|cancel|confirm|submit|transfer|import|enable|disable|install|uninstall|login|logout|schedule|book|pay|order|purchase|click|type|fill|navigate|evaluate|batch|mutate|upsert|configure|provision'
# ... and these as substrings, to catch run-together names like `getsendstatus`.
MCP_WRITE_SUBSTR='send|post|create|delete|remove|write|publish|merge|update|upload|reply|comment|notify|assign|replace|clear|save|submit|execute|kill|drop'

# check_mcp ENTRY — prints a reason and returns 1 unless the tool is read-only by name
check_mcp() {
  local rest server tool norm srv
  rest=${1#mcp__}
  [[ "$rest" =~ ^[A-Za-z0-9][A-Za-z0-9_-]*__[A-Za-z0-9][A-Za-z0-9_-]*$ ]] \
    || { echo "not a single-tool MCP entry (whole-server or malformed names are refused)"; return 1; }
  server=${rest%%__*}
  tool=${rest#*__}
  [[ "$tool" != *__* ]] || { echo "ambiguous server/tool split"; return 1; }
  case "${server}__${tool}" in
    nixos__nix | nixos__nix_versions) return 0 ;;   # the two read-only nixos tools already in use
  esac
  norm=$(sed -E 's/([a-z0-9])([A-Z])/\1_\2/g; s/-/_/g' <<< "$tool" | tr '[:upper:]' '[:lower:]')
  srv=$(tr '[:upper:]-' '[:lower:]_' <<< "$server")
  [[ "$norm" == "${srv}_"* ]] && norm=${norm#"${srv}_"}   # tailscale_list_devices -> list_devices
  [[ "$norm" =~ $MCP_READ_RE ]] || { echo "MCP tool name does not start with a read verb"; return 1; }
  if [[ "_${norm}_" =~ _(${MCP_WRITE_WORDS})_ ]] || [[ "$norm" =~ (${MCP_WRITE_SUBSTR}) ]]; then
    echo "MCP tool name contains a write/act verb"
    return 1
  fi
  return 0
}

# check_bash ENTRY — prints a reason and returns 1 unless the entry is an allowlisted read-only form
check_bash() {
  local entry=$1 arg base glob=0
  arg=${entry#Bash(}
  arg=${arg%)}
  if [ -z "$arg" ] || [[ "$arg" == '*' ]]; then
    echo "wildcard (or empty) command head"
    return 1
  fi
  if ! [[ "$arg" =~ $CHARS_RE ]]; then
    echo "characters outside [A-Za-z0-9 ._/~*-] (quotes, '=', ':', '$', non-ASCII, ...)"
    return 1
  fi
  if [[ "$arg" == *..* ]]; then
    echo "contains '..'"
    return 1
  fi
  if [[ "$arg" == ' '* || "$arg" == *' ' || "$arg" == *'  '* ]]; then
    echo "non-canonical whitespace (leading, trailing or repeated spaces)"
    return 1
  fi
  if [[ "$entry" =~ $SENSITIVE_RE ]]; then
    echo "mentions a credential / secret location"
    return 1
  fi
  if [[ "$arg" == *' *' ]]; then
    base=${arg% \*}
    glob=1
  elif [[ "$arg" == *'*' ]]; then
    base=${arg%\*}
    glob=1
  else
    base=$arg
  fi
  if [[ "$base" == *'*'* ]]; then
    echo "'*' is only allowed as the final character"
    return 1
  fi
  [ -n "$base" ] || { echo "wildcard (or empty) command head"; return 1; }
  if [[ "$base" =~ $SCRIPT_RE || "$base" =~ $GIT_RE || "$base" =~ $GIT_FETCH_RE || "$base" =~ $GH_RE \
    || "$base" =~ $NIX_RE || "$base" =~ $INSPECT_RE || "$base" =~ $SYSTEMCTL_RE || "$base" =~ $FLATPAK_RE ]]; then
    return 0
  fi
  echo "not in the read-only allowlist (default-deny)"
  return 1
}

while IFS= read -r entry; do
  [ -z "$entry" ] && continue
  if [[ "$entry" == mcp__* ]]; then
    why=$(check_mcp "$entry") || fail "added allow entry is not on the read-only allowlist: $entry ($why)"
  else
    why=$(check_bash "$entry") || fail "added allow entry is not on the read-only allowlist: $entry ($why)"
  fi
done <<< "$ADDED"

while IFS= read -r entry; do
  [ -z "$entry" ] && continue
  echo "ADDED: $entry"
done <<< "$ADDED"
exit 0
