#!/usr/bin/env bash
# check-settings-diff.test.sh — offline tests for check-settings-diff.sh.
#
# Usage: check-settings-diff.test.sh [path-to-check-settings-diff.sh]
#   Default target is the sibling script. For a mutation check, point it at an OLDER copy:
#   the cases tagged [new] cover the fixes and should fail there, [regress] ones should pass.
#
# Every case feeds ONE candidate allow entry to the checker as a freshly ADDED entry
# (base allow list = [Bash(zz-base-marker)], never judged) and expects it to be refused (rc 1) or accepted (rc 0).
# The real .claude/settings.json of this checkout is used for the "unchanged file" and
# "re-added entry" cases. Exit 0 when every case behaves as expected, 1 otherwise.
set -uo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "$HERE/../../../.." && pwd)
CHECKER=${1:-$HERE/check-settings-diff.sh}
REAL_SETTINGS="$REPO_ROOT/.claude/settings.json"
[ -x "$CHECKER" ] || { echo "checker not executable: $CHECKER" >&2; exit 2; }
[ -f "$REAL_SETTINGS" ] || { echo "missing $REAL_SETTINGS" >&2; exit 2; }

T=$(mktemp -d) || exit 2
trap 'rm -rf "$T"' EXIT
echo '{"permissions":{"allow":["Bash(zz-base-marker)"]}}' > "$T/base.json"

PASS_regress=0 FAIL_regress=0 PASS_new=0 FAIL_new=0
FAILED_NAMES=""

# chk TAG EXPECT ENTRY — EXPECT is "refuse" or "pass"
chk() {
  local tag=$1 expect=$2 entry=$3 out rc want=1
  [ "$expect" = pass ] && want=0
  jq -n --arg e "$entry" '{"permissions":{"allow":["Bash(zz-base-marker)",$e]}}' > "$T/head.json"
  out=$("$CHECKER" "$T/base.json" "$T/head.json" 2>&1)
  rc=$?
  if [ "$rc" -eq "$want" ]; then
    eval "PASS_$tag=\$((PASS_$tag + 1))"
    [ -n "${SHOW:-}" ] && printf 'ok   [%s] %-7s rc=%s %-62s %s\n' "$tag" "$expect" "$rc" "$entry" "${out#REASON: }"
  else
    eval "FAIL_$tag=\$((FAIL_$tag + 1))"
    printf 'FAIL [%s] wanted %s, rc=%s: %s -- %s\n' "$tag" "$expect" "$rc" "$entry" "${out#REASON: }"
    FAILED_NAMES+="  [$tag] $expect $entry"$'\n'
  fi
  return 0
}

# run_list TAG EXPECT LIST — LIST is newline-separated entries
run_list() {
  local tag=$1 expect=$2 e
  while IFS= read -r e; do
    [ -n "$e" ] && chk "$tag" "$expect" "$e"
  done <<< "$3"
}

# is_glued ENTRY — true for a Bash entry whose final '*' is glued to a word (not ' *')
is_glued() {
  local arg=${1#Bash(}
  arg=${arg%)}
  [[ "$1" == Bash\(* && "$arg" == *'*' && "$arg" != *' *' && "$arg" != '*' ]]
}

# ---- 1. The 84-entry refusal list from the original review: everything must stay refused ----
REFUSE_84=$(cat << 'EOF'
Bash(git --no-pager push*)
Bash(git -P push*)
Bash(git --git-dir=/home/bosko/NixOS/.git push*)
Bash(python3.12 -c *)
Bash(python3.13 -c *)
Bash(nodejs -e *)
Bash(ksh -c *)
Bash(nix --extra-experimental-features nix-command run*)
Bash(gh  pr merge*)
Bash(git  push*)
Bash(nix  run*)
Bash(gh  api*)
Bash(nix-build *)
Bash(nix-instantiate *)
Bash(nix-store --delete *)
Bash(niri *)
Bash(hyprctl *)
Bash(tmux *)
Bash(kitty @ *)
Bash(flatpak-spawn *)
Bash(fd *)
Bash(rg --pre *)
Bash(sort *)
Bash(tar *)
Bash(git grep -O*)
Bash(git log --output=/home/bosko/.bashrc)
Bash(cat ~/.config/gh/hosts.yml)
Bash(cat ~/.docker/config.json)
Bash(cat ~/.kube/config)
Bash(cat /etc/wireguard/wg0.key)
Bash(cat ~/.local/share/keyrings/login.keyring)
Bash(cat *)
Bash(rm *)
Bash(sudo *)
Bash(curl *)
Bash(gh pr merge*)
Bash( *)
Bash(/*)
Bash(*)
Bash(gh pr merge --admin *)
Bash(git -C /home/bosko/NixOS push*)
Bash(git -C /tmp/x status)
Bash(git -c core.pager=sh log)
Bash(git log -c *)
Bash(gh api *)
Bash(gh --repo CommanderBosko/NixOS pr view*)
Bash(bash -c *)
Bash(bash /tmp/evil.sh)
Bash(python3 .claude/skills/x/scripts/y.py *)
Bash(.claude/skills/../../usr/bin/rm *)
Bash(/home/bosko/NixOS/.claude/*)
Bash(.claude/skills/x/y.sh *)
Bash(.claude/skills/x/scripts/y *)
Bash(journalctl --vacuum-size=1M)
Bash(systemctl --user status*)
Bash(systemctl restart *)
Bash(ls | sh)
Bash(ls;rm x)
Bash(ls $(rm x))
Bash(echo ok > ~/.bashrc)
Bash(r\m *)
Bash("rm" *)
Bash(FOO=1 ls)
mcp__claude_ai_Gmail__send_email
mcp__claude_ai_Gmail__comment
mcp__claude_ai_Gmail
mcp__github__*
mcp__x__postmessage
mcp__x__addcomment
mcp__x__replyto
mcp__x__message_slack
mcp__x__save_note
mcp__x__notify_user
mcp__x__replace_text
mcp__x__assign_issue
mcp__x__clear_cache
mcp__x__getSendStatus
mcp__x__get_and_delete
mcp__x__getsendstatus
mcp__x__find_and_replace
mcp__x__Read__Something
mcp__x__
mcp__tailscale__tailscale_delete_device
mcp__tailscale__tailscale_set_acl
EOF
)
echo "== 84-entry refusal list (must all stay refused)"
run_list regress refuse "$REFUSE_84"

# ---- 2. The 36 benign entries: pass unless the entry is a glued-'*' Bash form ----
BENIGN_36=$(cat << 'EOF'
Bash(git status)
Bash(git status*)
Bash(git log --oneline*)
Bash(git diff --stat)
Bash(git show *)
Bash(git -C /home/bosko/NixOS rev-parse *)
Bash(gh pr view *)
Bash(gh pr list*)
Bash(gh pr checks*)
Bash(gh pr diff*)
Bash(gh run list*)
Bash(gh run view*)
Bash(nix flake show*)
Bash(ls *)
Bash(df -h*)
Bash(du -sh *)
Bash(wc *)
Bash(stat *)
Bash(uname -a)
Bash(which *)
Bash(systemctl status *)
Bash(systemctl is-active *)
Bash(journalctl -b*)
Bash(flatpak list*)
Bash(bash .claude/skills/foo/scripts/bar.sh *)
Bash(~/.claude/skills/lib/foo.sh*)
mcp__nixos__nix
mcp__nixos__nix_versions
mcp__github__get_file_contents
mcp__github__list_pull_requests
mcp__x__search_threads
mcp__x__getStatus
mcp__x__Get_Thing
mcp__tailscale__tailscale_list_devices
mcp__tailscale__tailscale_get_acl
mcp__tailscale__tailscale_status
EOF
)
echo "== 36 benign entries (the glued-'*' ones are now refused by design)"
n_benign=0 n_benign_glued=0
while IFS= read -r e; do
  [ -n "$e" ] || continue
  n_benign=$((n_benign + 1))
  if is_glued "$e"; then
    n_benign_glued=$((n_benign_glued + 1))
    chk new refuse "$e"
    # the same command in the ' *' form must pass: the fix is a one-character edit
    if [ "${e%\*)}" != "$e" ]; then chk regress pass "${e%\*)} *)"; fi
  else
    chk regress pass "$e"
  fi
done <<< "$BENIGN_36"
echo "   $n_benign benign entries: $((n_benign - n_benign_glued)) still pass, $n_benign_glued glued-'*' forms now refused"

# ---- 3. Glued '*' (command-name prefix match) vs the ' *' form ----
echo "== glued '*' refused, ' *' accepted"
run_list new refuse "$(cat << 'EOF'
Bash(ls*)
Bash(du*)
Bash(id*)
Bash(wc -l*)
Bash(git diff*)
Bash(git log*)
Bash(git -C /home/bosko/NixOS diff*)
Bash(lsblk*)
Bash(journalctl*)
Bash(git fetch*)
Bash(nix eval*)
Bash(nix flake check*)
Bash(gh run watch*)
Bash(flatpak remote-info*)
Bash(.claude/skills/x/scripts/y.sh*)
Bash(bash .claude/skills/x/scripts/y.sh*)
Bash(~/.claude/skills/lib/x.sh*)
Bash(/home/bosko/NixOS/.claude/lib/x.sh*)
Bash(/home/bosko/NixOS/.claude/skills/x/scripts/y.sh*)
EOF
)"
run_list regress pass "$(cat << 'EOF'
Bash(ls)
Bash(ls -la)
Bash(ls *)
Bash(du *)
Bash(id *)
Bash(wc -l *)
Bash(git status)
Bash(git status *)
Bash(git diff *)
Bash(git -C /home/bosko/NixOS diff *)
Bash(git -C /home/bosko/NixOS log *)
Bash(lsblk *)
Bash(journalctl *)
Bash(git fetch)
Bash(nix eval *)
Bash(nix flake check *)
Bash(gh run watch *)
Bash(flatpak remote-info *)
Bash(.claude/skills/x/scripts/y.sh *)
Bash(.claude/skills/x/scripts/y.sh)
Bash(bash .claude/skills/x/scripts/y.sh *)
Bash(~/.claude/skills/lib/x.sh *)
Bash(/home/bosko/NixOS/.claude/lib/x.sh *)
Bash(/home/bosko/NixOS/.claude/skills/x/scripts/y.sh *)
EOF
)"

# ---- 4. MCP name heuristics ----
echo "== MCP: credential-returning names, chained actions, laundered server prefixes"
run_list new refuse "$(cat << 'EOF'
mcp__x__get_secret
mcp__x__get_secret_value
mcp__x__get_access_token
mcp__x__read_password
mcp__x__list_api_keys
mcp__x__fetch_oauth_token
mcp__x__getAPIKey
mcp__x__getApiKey
mcp__x__get_session_key
mcp__x__get_cookies
mcp__x__get_private_key
mcp__x__read_credentials
mcp__x__get_passwd
mcp__x__GetToken
mcp__secrets__list_things
mcp__oauth_manager__get_status
mcp__x__search_and_purge
mcp__x__get_and_wipe
mcp__x__query_and_truncate
mcp__x__get_and_unlink
mcp__x__status_and_reboot
mcp__x__list_and_toggle
mcp__x__find_and_ban
mcp__x__getAndToggleLight
mcp__x__listandtoggle
mcp__x__getaway
mcp__x__readwrite
mcp__x__find_and_unlink
mcp__x__get_and_set
mcp__x__get_and_unset
mcp__x__ls_and_mv
mcp__x__list_or_create
mcp__x__get_then_run
mcp__x__get_purge_log
mcp__send__send_get_x
mcp__delete__delete_get_files
mcp__post__post_list_things
mcp__get__get_delete
mcp__x__list_and_open_door
mcp__x__search_and_destroy
EOF
)"
run_list regress refuse "$(cat << 'EOF'
mcp__x__get_and_download_install
mcp__x__describe_and_run
mcp__x__list_and_pay
mcp__x__read_and_delete
mcp__x__view_and_forward
mcp__x__search_and_kill
mcp__x__get__y
mcp__x__getSendStatus
mcp__x__sendMail
mcp__x__SendEmail
mcp__x__run_query
mcp__x__Delete
mcp__x__deletefile
mcp__github
mcp__github__
mcp__github__*
mcp__claude_ai_Gmail
mcp__claude_ai_Gmail__send_email
mcp__claude_ai_Gmail__create_draft
mcp__github__create_issue
mcp__nixos__nix_anything
mcp__nixos__nixos_execute
EOF
)"
run_list regress pass "$(cat << 'EOF'
mcp__nixos__nix
mcp__nixos__nix_versions
mcp__github__get_file_contents
mcp__github__list_pull_requests
mcp__x__search_threads
mcp__x__getStatus
mcp__x__Get_Thing
mcp__x__get_thread
mcp__x__read_file
mcp__x__get_status
mcp__x__status
mcp__x__ls
mcp__x__describe_table
mcp__x__x_get_y
mcp__claude_ai_Gmail__search_threads
mcp__tailscale__tailscale_list_devices
mcp__tailscale__tailscale_get_acl
mcp__tailscale__tailscale_status
EOF
)"

# ---- 5. The real settings.json ----
echo "== real .claude/settings.json"
N_REAL=$(jq '.permissions.allow | length' "$REAL_SETTINGS")
# 5a. The unchanged file must still pass: only ADDITIONS are judged, never existing entries.
out=$("$CHECKER" "$REAL_SETTINGS" "$REAL_SETTINGS" 2>&1)
rc=$?
if [ "$rc" -eq 0 ] && ! grep -q '^ADDED:' <<< "$out"; then
  PASS_regress=$((PASS_regress + 1))
  echo "ok   [regress] unchanged real settings.json ($N_REAL entries) passes with nothing added"
else
  FAIL_regress=$((FAIL_regress + 1))
  FAILED_NAMES+="  [regress] unchanged real settings.json: rc=$rc"$'\n'
  echo "FAIL [regress] unchanged real settings.json: rc=$rc $out"
fi
# 5b. Re-adding each real entry as if new: refused exactly when it is a glued-'*' Bash form.
mapfile -t REAL < <(jq -r '.permissions.allow[]' "$REAL_SETTINGS")
refused_if_readded=()
for e in "${REAL[@]}"; do
  if is_glued "$e"; then
    chk new refuse "$e"
    refused_if_readded+=("$e")
  else
    chk regress pass "$e"
  fi
done
echo "   ${#REAL[@]} real entries: $((${#REAL[@]} - ${#refused_if_readded[@]})) would still pass if re-added, ${#refused_if_readded[@]} would be refused (glued '*'):"
printf '     %s\n' "${refused_if_readded[@]}"

echo
echo "== summary: regress ${PASS_regress} pass / ${FAIL_regress} fail;  new ${PASS_new} pass / ${FAIL_new} fail"
if [ $((FAIL_regress + FAIL_new)) -ne 0 ]; then
  printf 'FAILED:\n%s' "$FAILED_NAMES"
  exit 1
fi
exit 0
