#!/usr/bin/env bash
# find-and-check-pr.test.sh — offline tests for find-and-check-pr.sh (a stub `gh` on PATH).
#
# Usage: find-and-check-pr.test.sh [path-to-find-and-check-pr.sh]
#   Default target is the sibling script. For a mutation check, point it at an OLDER copy
#   (that copy's own check-settings-diff.sh must sit next to it): the cases tagged [new]
#   should fail there, the [regress] ones should still pass.
#
# Never touches the network or the repo: gh is a stub driven by fixture files, and the real
# .claude/settings.json of this checkout is used as the PR base for the "real allow list"
# cases. Exit 0 when every case behaves as expected, 1 otherwise.
set -uo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "$HERE/../../../.." && pwd)
TARGET=${1:-$HERE/find-and-check-pr.sh}
REAL_SETTINGS="$REPO_ROOT/.claude/settings.json"
[ -x "$TARGET" ] || { echo "target not executable: $TARGET" >&2; exit 2; }
[ -f "$REAL_SETTINGS" ] || { echo "missing $REAL_SETTINGS" >&2; exit 2; }

T=$(mktemp -d) || exit 2
trap 'rm -rf "$T"' EXIT
BIN="$T/bin"
FX="$T/fx"
mkdir -p "$BIN"
BASE_OID=1111111111111111111111111111111111111111
HEAD_OID=2222222222222222222222222222222222222222

cat > "$BIN/gh" << 'STUB'
#!/usr/bin/env bash
# gh stub for find-and-check-pr.sh: canned fixtures from $FX; $FAIL picks a failure point.
JQ_EXPR=""
args=("$@")
for ((i = 0; i < ${#args[@]}; i++)); do
  [ "${args[i]}" = "--jq" ] && JQ_EXPR=${args[i + 1]}
done
emit() { if [ -n "$JQ_EXPR" ]; then jq -r "$JQ_EXPR" "$1"; else cat "$1"; fi; }
case "$1 $2" in
  "pr list")
    [ "$FAIL" = list ] && { echo "HTTP 401: Bad credentials" >&2; exit 1; }
    emit "$FX/list.json"
    ;;
  "pr view")
    [ "$FAIL" = view ] && { echo "error connecting to api.github.com" >&2; exit 1; }
    emit "$FX/view.json"
    ;;
  api*)
    case "$*" in
      *"/pulls/"*"/files"*)
        [ "$FAIL" = rest ] && { echo "HTTP 502" >&2; exit 1; }
        emit "$FX/rest.json"
        ;;
      *"ref=$BASE_OID"*)
        [ "$FAIL" = api_base ] && { echo "HTTP 502" >&2; exit 1; }
        cat "$FX/base-settings.json"
        ;;
      *"ref=$HEAD_OID"*)
        [ "$FAIL" = api_head ] && { echo "HTTP 502" >&2; exit 1; }
        cat "$FX/head-settings.json"
        ;;
      *) echo "gh stub: unhandled api: $*" >&2; exit 99 ;;
    esac
    ;;
  *)
    echo "gh stub: unhandled: $*" >&2
    exit 99
    ;;
esac
STUB
chmod +x "$BIN/gh"

# fx_setup SPEC — build the fixtures for one PR. SPEC is a newline-separated changed-file
# list; a line "old -> new" is a rename (gh's `files` lists only `new`; the REST list adds
# previous_filename=old). Env knobs: NO_PR=1, BASE_SETTINGS=<file>, HEAD_SETTINGS=<file>.
fx_setup() {
  local spec=$1
  rm -rf "$FX"
  mkdir -p "$FX"
  if [ -n "${NO_PR:-}" ]; then
    jq -nc '[{number:5,title:"other",headRefName:"fix/x",url:"u",body:""}]' > "$FX/list.json"
  else
    jq -nc '[{number:99,title:"improve-system weekly sweep",headRefName:"improve-system/weekly-2026-11-01",url:"https://example/pull/99",body:"body text"},{number:5,title:"other",headRefName:"fix/x",url:"u",body:""}]' > "$FX/list.json"
  fi
  local parsed
  parsed='($s | split("\n") | map(select(length > 0)) | map(split(" -> ") | {old: (if length == 2 then .[0] else null end), p: .[-1]}))'
  jq -nc --arg s "$spec" --arg b "$BASE_OID" --arg h "$HEAD_OID" \
    "$parsed"' as $f | {files: ($f | map({path: .p, additions: 1, deletions: 0, changeType: "MODIFIED"})), baseRefOid: $b, headRefOid: $h}' > "$FX/view.json"
  jq -nc --arg s "$spec" \
    "$parsed"' as $f | $f | map({filename: .p, status: (if .old then "renamed" else "modified" end), previous_filename: .old})' > "$FX/rest.json"
  cp "${BASE_SETTINGS:-$REAL_SETTINGS}" "$FX/base-settings.json"
  cp "${HEAD_SETTINGS:-$FX/base-settings.json}" "$FX/head-settings.json"
}

PASS_regress=0 FAIL_regress=0 PASS_new=0 FAIL_new=0
FAILED_NAMES=""

# t TAG NAME WANT_RC SPEC [PATTERN...] — run the target against one fixture PR.
# A PATTERN must appear in the output; one starting with '!' must not.
t() {
  local tag=$1 name=$2 want=$3 spec=$4 p ok=1 why="" out rc
  shift 4
  fx_setup "$spec"
  out=$(PATH="$BIN:$PATH" FX="$FX" FAIL="${FAIL:-}" BASE_OID="$BASE_OID" HEAD_OID="$HEAD_OID" "$TARGET" 2>&1)
  rc=$?
  [ "$rc" -eq "$want" ] || { ok=0; why="rc=$rc, wanted $want"; }
  for p in "$@"; do
    if [[ "$p" == '!'* ]]; then
      if grep -qF -- "${p#!}" <<< "$out"; then ok=0; why+="; unexpected '${p#!}'"; fi
    else
      grep -qF -- "$p" <<< "$out" || { ok=0; why+="; missing '$p'"; }
    fi
  done
  if [ "$ok" -eq 1 ]; then
    printf 'PASS [%s] %s\n' "$tag" "$name"
    eval "PASS_$tag=\$((PASS_$tag + 1))"
  else
    printf 'FAIL [%s] %s -- %s\n' "$tag" "$name" "$why"
    eval "FAIL_$tag=\$((FAIL_$tag + 1))"
    FAILED_NAMES+="  [$tag] $name"$'\n'
    [ -n "${VERBOSE:-}" ] && sed 's/^/        | /' <<< "$out"
  fi
  [ -n "${SHOW:-}" ] && sed 's/^/        | /' <<< "$out"
  return 0
}

TINY="$T/tiny.json"
echo '{"permissions":{"allow":["Bash(ls *)"]}}' > "$TINY"
echo '{"permissions":{"allow":["Bash(ls *)","Bash(df -h *)"]}}' > "$T/tiny-df.json"
echo '{"permissions":{"allow":["Bash(ls *)","Bash(rm *)"]}}' > "$T/tiny-rm.json"
HOOK="$T/hook.json"
echo '{"permissions":{"allow":["Bash(ls *)"]},"hooks":{"SessionStart":[{"hooks":[{"type":"command","command":"bash /home/bosko/NixOS/.claude/skills/foo/scripts/hook.sh"}]}]}}' > "$HOOK"
ALT="$T/alt.json"
echo '{"permissions":{"allow":["Bash(/srv/alt/NixOS/.claude/skills/foo/scripts/x.sh *)"]}}' > "$ALT"

# Real settings + a new script entry (the shim-PR attack: add a script AND its allow entry).
add_entry() { jq --arg e "$2" '.permissions.allow += [$e]' "$REAL_SETTINGS" > "$1"; }
add_entry "$T/head-evil-rel.json" 'Bash(bash .claude/skills/x/scripts/evil.sh *)'
add_entry "$T/head-evil-home.json" 'Bash(~/.claude/skills/x/scripts/evil.sh *)'
add_entry "$T/head-evil-abs.json" 'Bash(/home/bosko/NixOS/.claude/skills/x/scripts/evil.sh *)'
add_entry "$T/head-evil-lib.json" 'Bash(bash .claude/lib/evil.sh *)'
jq . "$REAL_SETTINGS" | jq -c . > "$T/head-reformatted.json"   # same content, different bytes

echo "== target: $TARGET"
echo "== regressions: behaviour that must not change"
NO_PR=1 t regress "no open weekly PR -> 1" 1 ".claude/skills/a/SKILL.md" "NO_PR" "!GUARDRAIL"
FAIL=list t regress "gh pr list fails -> 3, not 'no PR'" 3 ".claude/skills/a/SKILL.md" "GUARDRAIL: NOT EVALUATED" "!NO_PR" "!GUARDRAIL: OK"
FAIL=view t regress "gh pr view fails -> 3" 3 ".claude/skills/a/SKILL.md" "GUARDRAIL: NOT EVALUATED" "!GUARDRAIL: OK"
t regress "no changed files -> 3" 3 "" "GUARDRAIL: NOT EVALUATED" "!GUARDRAIL: OK"
t regress "100 changed files -> 3 (possibly truncated)" 3 "$(for i in $(seq 0 99); do echo ".claude/skills/x/references/f$i.md"; done)" "GUARDRAIL: NOT EVALUATED" "!GUARDRAIL: OK"
BASE_SETTINGS=$TINY t regress "healthy skill PR (SKILL.md + scripts/) -> 0" 0 \
  $'.claude/skills/a/SKILL.md\ndotfiles/bosko/claude/skills/b/scripts/x.sh' "GUARDRAIL: OK" "PR_HEAD_SHA: $HEAD_OID"
BASE_SETTINGS=$TINY t regress "flake.nix -> 2" 2 $'.claude/skills/a/SKILL.md\nflake.nix' "GUARDRAIL: VIOLATION" "flake.nix" "!GUARDRAIL: OK"
BASE_SETTINGS=$TINY t regress "NOTSKILL.md is not SKILL.md -> 2" 2 ".claude/skills/a/NOTSKILL.md" "GUARDRAIL: VIOLATION"
BASE_SETTINGS=$TINY t regress "nested path outside the boundary -> 2" 2 ".claude/skills/a/b/SKILL.md" "GUARDRAIL: VIOLATION"
BASE_SETTINGS=$TINY HEAD_SETTINGS=$T/tiny-rm.json t regress "settings: Bash(rm *) added -> 2" 2 \
  $'.claude/skills/a/SKILL.md\n.claude/settings.json' "GUARDRAIL: VIOLATION" ".claude/settings.json" "Bash(rm *)"
BASE_SETTINGS=$TINY HEAD_SETTINGS=$T/tiny-df.json t regress "settings: benign read-only entry added -> 0" 0 \
  $'.claude/skills/a/SKILL.md\n.claude/settings.json' "GUARDRAIL: OK" "SETTINGS_ALLOW_ADDED:" "Bash(df -h *)"
FAIL=api_head BASE_SETTINGS=$TINY t regress "settings.json head fetch fails -> 3" 3 \
  $'.claude/skills/a/SKILL.md\n.claude/settings.json' "GUARDRAIL: NOT EVALUATED" "!GUARDRAIL: VIOLATION" "!GUARDRAIL: OK"
FAIL=api_base BASE_SETTINGS=$TINY t regress "settings.json base fetch fails (settings in PR) -> 3" 3 \
  $'.claude/skills/a/SKILL.md\n.claude/settings.json' "GUARDRAIL: NOT EVALUATED" "!GUARDRAIL: OK"
t regress "real allow list, skill-docs-only PR -> 0" 0 \
  $'.claude/skills/a/SKILL.md\n.claude/skills/a/references/notes.md\ndotfiles/bosko/claude/skills/b/SKILL.md' "GUARDRAIL: OK"
HEAD_SETTINGS=$T/head-reformatted.json t regress "settings.json touched but allow list unchanged (real list) -> 0" 0 \
  $'.claude/skills/a/SKILL.md\n.claude/settings.json' "GUARDRAIL: OK" "!SETTINGS_ALLOW_ADDED"

echo "== new: edits to scripts that settings.json lets run unprompted"
t new "edit secret-scan.sh (allow entry) -> 2" 2 ".claude/skills/secret-scan/scripts/secret-scan.sh" \
  "GUARDRAIL: VIOLATION" ".claude/skills/secret-scan/scripts/secret-scan.sh" "without a permission prompt" "secret-scan.sh*" "!GUARDRAIL: OK"
t new "edit nixos-dry-run/dry-run.sh -> 2" 2 ".claude/skills/nixos-dry-run/scripts/dry-run.sh" \
  "GUARDRAIL: VIOLATION" "without a permission prompt" "dry-run.sh"
t new "edit deep-eval-check.sh -> 2" 2 ".claude/skills/deep-eval-check/scripts/deep-eval-check.sh" \
  "GUARDRAIL: VIOLATION" "without a permission prompt" "deep-eval-check.sh"
t new "edit session-closer scan-session.sh via ~/.claude mapping -> 2" 2 "dotfiles/bosko/claude/skills/session-closer/scripts/scan-session.sh" \
  "GUARDRAIL: VIOLATION" "without a permission prompt" "scan-session.sh"
t new "edit skill-upgrade find-skill-misfires.sh via ~/.claude mapping -> 2" 2 "dotfiles/bosko/claude/skills/skill-upgrade/scripts/find-skill-misfires.sh" \
  "GUARDRAIL: VIOLATION" "without a permission prompt" "find-skill-misfires.sh"
t new "edit secret-scan.sh AND scan-session.sh together -> 2, both named" 2 \
  $'.claude/skills/secret-scan/scripts/secret-scan.sh\ndotfiles/bosko/claude/skills/session-closer/scripts/scan-session.sh' \
  "GUARDRAIL: VIOLATION" "  .claude/skills/secret-scan/scripts/secret-scan.sh (" "  dotfiles/bosko/claude/skills/session-closer/scripts/scan-session.sh ("
t new "file sharing a trusted script's name prefix (glued '*' = prefix match) -> 2" 2 ".claude/skills/secret-scan/scripts/secret-scan.sh.bak" \
  "GUARDRAIL: VIOLATION" "without a permission prompt"
t new "edit .claude/lib/flake-lock-diff.sh (allow entry + shared lib) -> 2" 2 ".claude/lib/flake-lock-diff.sh" \
  "GUARDRAIL: VIOLATION" "flake-lock-diff.sh"
t new "edit ~/.claude skills lib script via dotfiles mapping -> 2" 2 "dotfiles/bosko/claude/skills/lib/scope-since-last-run.sh" \
  "GUARDRAIL: VIOLATION" "scope-since-last-run.sh"
BASE_SETTINGS=$HOOK t new "edit a script a settings.json HOOK runs -> 2" 2 ".claude/skills/foo/scripts/hook.sh" \
  "GUARDRAIL: VIOLATION" "without a permission prompt" "hook.sh"
BASE_SETTINGS=$ALT REVIEW_SAFE_HOME=/srv/alt t new "REVIEW_SAFE_HOME-rooted entry maps to the repo path -> 2" 2 ".claude/skills/foo/scripts/x.sh" \
  "GUARDRAIL: VIOLATION" "without a permission prompt"
BASE_SETTINGS=$ALT REVIEW_SAFE_HOME='not/absolute' t new "invalid REVIEW_SAFE_HOME -> 3" 3 ".claude/skills/foo/SKILL.md" \
  "GUARDRAIL: NOT EVALUATED" "!GUARDRAIL: OK"

echo "== new: adding a script together with an allow entry for it"
HEAD_SETTINGS=$T/head-evil-rel.json t new "add evil.sh + 'bash .claude/...' entry -> 2 (checker alone passes the entry)" 2 \
  $'.claude/skills/x/scripts/evil.sh\n.claude/settings.json' \
  "SETTINGS_ALLOW_ADDED:" "Bash(bash .claude/skills/x/scripts/evil.sh *)" "GUARDRAIL: VIOLATION" "  .claude/skills/x/scripts/evil.sh (" "!GUARDRAIL: OK"
HEAD_SETTINGS=$T/head-evil-home.json t new "add evil.sh + '~/.claude/...' entry (dotfiles path) -> 2" 2 \
  $'dotfiles/bosko/claude/skills/x/scripts/evil.sh\n.claude/settings.json' \
  "GUARDRAIL: VIOLATION" "  dotfiles/bosko/claude/skills/x/scripts/evil.sh ("
HEAD_SETTINGS=$T/head-evil-abs.json t new "add evil.sh + absolute /home/bosko/NixOS/... entry -> 2" 2 \
  $'.claude/skills/x/scripts/evil.sh\n.claude/settings.json' \
  "GUARDRAIL: VIOLATION" "  .claude/skills/x/scripts/evil.sh ("
HEAD_SETTINGS=$T/head-evil-lib.json t new "add .claude/lib/evil.sh + entry -> 2" 2 \
  $'.claude/lib/evil.sh\n.claude/settings.json' \
  "GUARDRAIL: VIOLATION" "  .claude/lib/evil.sh ("
HEAD_SETTINGS=$T/head-evil-rel.json t regress "allow entry added but the script is NOT in the PR (known residual) -> 0" 0 \
  $'.claude/skills/a/SKILL.md\n.claude/settings.json' \
  "GUARDRAIL: OK" "SETTINGS_ALLOW_ADDED:"

echo "== new: shared libs"
t new "edit .claude/lib/hosts.sh (sourced, not allow-listed) -> 2" 2 ".claude/lib/hosts.sh" \
  "GUARDRAIL: VIOLATION" "shared helper"
t new "edit .claude/skills/lib/x.sh -> 2" 2 ".claude/skills/lib/x.sh" \
  "GUARDRAIL: VIOLATION" "shared helper"
t new "edit dotfiles/bosko/claude/skills/lib/find-transcript-dir.sh -> 2" 2 "dotfiles/bosko/claude/skills/lib/find-transcript-dir.sh" \
  "GUARDRAIL: VIOLATION"

echo "== new: gate self-edit"
t new "edit review-improve-system-pr/SKILL.md -> 2" 2 ".claude/skills/review-improve-system-pr/SKILL.md" \
  "GUARDRAIL: VIOLATION" "review gate" "!GUARDRAIL: OK"
t new "edit review-improve-system-pr check-settings-diff.sh -> 2" 2 ".claude/skills/review-improve-system-pr/scripts/check-settings-diff.sh" \
  "GUARDRAIL: VIOLATION" "review gate"
t new "edit review-improve-system-pr ci-gate.sh -> 2" 2 ".claude/skills/review-improve-system-pr/scripts/ci-gate.sh" \
  "GUARDRAIL: VIOLATION" "review gate"
t new "edit review-improve-system-pr find-and-check-pr.sh -> 2" 2 ".claude/skills/review-improve-system-pr/scripts/find-and-check-pr.sh" \
  "GUARDRAIL: VIOLATION" "review gate"
t new "edit review-improve-system-pr references/gotchas.md -> 2" 2 ".claude/skills/review-improve-system-pr/references/gotchas.md" \
  "GUARDRAIL: VIOLATION" "review gate"
t new "add a test file under review-improve-system-pr/scripts -> 2" 2 ".claude/skills/review-improve-system-pr/scripts/new.test.sh" \
  "GUARDRAIL: VIOLATION" "review gate"
t new "edit improve-system/SKILL.md -> 2" 2 "dotfiles/bosko/claude/skills/improve-system/SKILL.md" \
  "GUARDRAIL: VIOLATION" "improve-system" "!GUARDRAIL: OK"
t new "edit improve-system/scripts/write-report.sh -> 2" 2 "dotfiles/bosko/claude/skills/improve-system/scripts/write-report.sh" \
  "GUARDRAIL: VIOLATION"
t new "edit improve-system/references/gotchas.md -> 2" 2 "dotfiles/bosko/claude/skills/improve-system/references/gotchas.md" \
  "GUARDRAIL: VIOLATION"
t new "gate dir mixed into an otherwise healthy PR -> 2, only the gate file named" 2 \
  $'.claude/skills/a/SKILL.md\ndotfiles/bosko/claude/skills/b/references/r.md\n.claude/skills/review-improve-system-pr/SKILL.md' \
  "GUARDRAIL: VIOLATION" "  .claude/skills/review-improve-system-pr/SKILL.md (" "!  .claude/skills/a/SKILL.md ("

echo "== new: renames and deletes"
t new "rename OUT of a trusted script path -> 2, old path named" 2 \
  ".claude/skills/secret-scan/scripts/secret-scan.sh -> .claude/skills/secret-scan/references/old.md" \
  "PR_RENAMED_FROM:" "GUARDRAIL: VIOLATION" "  .claude/skills/secret-scan/scripts/secret-scan.sh ("
t new "rename OUT of the gate dir -> 2, old path named" 2 \
  ".claude/skills/review-improve-system-pr/SKILL.md -> .claude/skills/other/SKILL.md" \
  "GUARDRAIL: VIOLATION" "  .claude/skills/review-improve-system-pr/SKILL.md ("
t new "harmless rename between two unrelated skill docs -> 0, old name listed" 0 \
  ".claude/skills/a/references/old.md -> .claude/skills/a/references/new.md" "GUARDRAIL: OK" "PR_RENAMED_FROM:"
FAIL=rest t new "rename-list fetch fails -> 3, never OK" 3 ".claude/skills/a/SKILL.md" \
  "GUARDRAIL: NOT EVALUATED" "!GUARDRAIL: OK"
t new "delete of a trusted script (listed by gh under its old path) -> 2" 2 ".claude/skills/deep-eval-check/scripts/deep-eval-check.sh" \
  "GUARDRAIL: VIOLATION"
FAIL=api_base t new "settings.json untouched but base fetch fails -> 3 (trusted set unknown)" 3 ".claude/skills/a/SKILL.md" \
  "GUARDRAIL: NOT EVALUATED" "!GUARDRAIL: OK"

echo "== new: no over-flagging of unrelated skills"
t new "unrelated skill SKILL.md + references + scripts (real allow list) -> 0" 0 \
  $'.claude/skills/unrelated-skill/SKILL.md\n.claude/skills/unrelated-skill/references/gotchas.md\n.claude/skills/unrelated-skill/scripts/helper.sh\ndotfiles/bosko/claude/skills/another/SKILL.md' \
  "GUARDRAIL: OK" "!VIOLATION"
t new "sibling skill dir next to a trusted one (secret-scan/SKILL.md) -> 0" 0 \
  $'.claude/skills/secret-scan/SKILL.md\n.claude/skills/secret-scan/references/notes.md' "GUARDRAIL: OK"

echo
echo "== summary: regress ${PASS_regress} pass / ${FAIL_regress} fail;  new ${PASS_new} pass / ${FAIL_new} fail"
if [ $((FAIL_regress + FAIL_new)) -ne 0 ]; then
  printf 'FAILED:\n%s' "$FAILED_NAMES"
  exit 1
fi
exit 0
