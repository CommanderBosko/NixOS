#!/usr/bin/env bash
# Self-contained test for `merge-step.sh wait` and `merge`: a PATH-shimmed `gh` replays a scripted
# sequence of rollups/failures, so the CI-wait logic is exercised without GitHub.
# Covers: pass / red / pending->pass, persistent gh failure (exit 4, never "still pending"),
# transient gh failure recovery, cap hit while failing, an empty rollup after checks were
# seen (must not exit 0), a repo that never reports any checks (exit 0 after the grace), and
# `merge` (head pinning via --match-head-commit, exit 5 when the post-merge state check fails).
set -euo pipefail

STEP="$(cd "$(dirname "$0")" && pwd)/merge-step.sh"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT

# The shim reads its scenario from $GH_SEQ: one token per line, line N answers the Nth call,
# the last line repeats forever. Tokens: PENDING PASS RED EMPTY FAIL BLANK (blank = rc 0, no output).
HEAD_SHA=0123456789abcdef0123456789abcdef01234567
export GH_HEAD="$HEAD_SHA" GH_MERGE_LOG="$T/merge.log"
mkdir "$T/bin"
cat >"$T/bin/gh" <<'GH'
#!/usr/bin/env bash
# `gh pr merge ...` logs its argv and exits $GH_MERGE_RC (default 0).
if [ "${1:-} ${2:-}" = "pr merge" ]; then echo "$*" >>"$GH_MERGE_LOG"; exit "${GH_MERGE_RC:-0}"; fi
# `gh pr view --json state,mergeCommit --jq ...` answers post-jq: $GH_STATE_OUT, or fails if GH_STATE_FAIL=1.
case "$*" in
  *state,mergeCommit*)
    if [ "${GH_STATE_FAIL:-0}" = 1 ]; then echo "gh: HTTP 502 (stub)" >&2; exit 1; fi
    echo "${GH_STATE_OUT:-MERGED abc1234}"; exit 0 ;;
  *"--json headRefOid --jq"*) echo "$GH_HEAD"; exit 0 ;;
esac
# otherwise: the rollup query, scripted by $GH_SEQ
c=$(cat "$GH_COUNT" 2>/dev/null || echo 0); c=$((c + 1)); echo "$c" >"$GH_COUNT"
tok=$(sed -n "${c}p" "$GH_SEQ"); [ -n "$tok" ] || tok=$(tail -n 1 "$GH_SEQ")
h="\"headRefOid\":\"$GH_HEAD\""
case "$tok" in
  PENDING) echo '{"statusCheckRollup":[{"__typename":"CheckRun","name":"flake-check","status":"IN_PROGRESS","conclusion":""}],'"$h"'}' ;;
  PASS)    echo '{"statusCheckRollup":[{"__typename":"CheckRun","name":"flake-check","status":"COMPLETED","conclusion":"SUCCESS"}],'"$h"'}' ;;
  RED)     echo '{"statusCheckRollup":[{"__typename":"CheckRun","name":"flake-check","status":"COMPLETED","conclusion":"FAILURE"}],'"$h"'}' ;;
  EMPTY)   echo '{"statusCheckRollup":[],'"$h"'}' ;;
  FAIL)    echo "gh: HTTP 502 (stub)" >&2; exit 1 ;;
  BLANK)   ;;
  *)       echo "bad stub token: $tok" >&2; exit 99 ;;
esac
GH
chmod +x "$T/bin/gh"
export PATH="$T/bin:$PATH"
export GH_COUNT="$T/count" GH_SEQ="$T/seq"
export MERGE_STEP_POLL_SECS=0.2 MERGE_STEP_NO_CHECKS_GRACE_SECS=1

fail() { echo "FAIL: $*" >&2; echo "--- output:" >&2; echo "$OUT" >&2; exit 1; }

# run <expected-rc> <wait-args...> with the scenario in $SEQ (newline-separated tokens);
# leaves the combined stdout+stderr in $OUT and the number of gh calls in $CALLS.
run() {
  local want="$1" rc=0; shift
  printf '%s\n' $SEQ >"$GH_SEQ"; rm -f "$GH_COUNT"
  OUT="$("$STEP" wait 7 "$@" 2>&1)" || rc=$?
  CALLS=$(cat "$GH_COUNT" 2>/dev/null || echo 0)
  [ "$rc" -eq "$want" ] || fail "[$SEQ] wait $* exited $rc, want $want"
}

# --- baseline behaviours stay intact ---
SEQ="PASS"; run 0 30
grep -q "checks passed" <<<"$OUT" || fail "pass: missing 'checks passed'"

SEQ="PENDING PENDING PASS"; run 0 30
grep -q "checks passed" <<<"$OUT" || fail "pending->pass: missing 'checks passed'"

SEQ="PENDING RED"; run 1 30
grep -q "failing checks: flake-check" <<<"$OUT" || fail "red: failing check not named"

SEQ="PENDING"; run 3 1
grep -q "still not finished" <<<"$OUT" || fail "pending cap: missing 'still not finished'"

# --- 5a: a persistent gh failure is exit 4, never "still pending" (exit 3) ---
SEQ="FAIL"; run 4 30
[ "$CALLS" -eq 5 ] || fail "persistent failure: expected 5 gh calls, got $CALLS"
grep -q "5 times in a row" <<<"$OUT" || fail "persistent failure: missing give-up message"
! grep -q "still not finished" <<<"$OUT" || fail "persistent failure reported as still pending"

# gh answering rc 0 with no output counts as a failure too
SEQ="BLANK"; run 4 30
! grep -q "still not finished" <<<"$OUT" || fail "blank output reported as still pending"

# the cap landing while the latest query is failing is also 4, not 3
SEQ="FAIL"; run 4 0
! grep -q "still not finished" <<<"$OUT" || fail "cap-while-failing reported as still pending"
grep -q "state unknown" <<<"$OUT" || fail "cap-while-failing: missing 'state unknown'"

# transient failures recover, and the consecutive count resets on a good answer
SEQ="FAIL FAIL FAIL FAIL PENDING FAIL FAIL FAIL FAIL PASS"; run 0 30
grep -q "checks passed" <<<"$OUT" || fail "transient failures: did not recover to pass"

# --- 5b: an empty rollup after checks were seen must not exit 0 early ---
SEQ="PENDING PENDING EMPTY"; run 3 3
! grep -q "nothing to wait for" <<<"$OUT" || fail "empty-after-seen exited 0 early"
grep -q "went empty" <<<"$OUT" || fail "empty-after-seen: missing 'went empty' message"
# ...but it recovers when the checks come back and finish
SEQ="PENDING EMPTY EMPTY PASS"; run 0 30
grep -q "checks passed" <<<"$OUT" || fail "empty blip then pass: missing 'checks passed'"
# ...and a red check after the blip still stops the wait
SEQ="PENDING EMPTY RED"; run 1 30

# a repo that never reports any checks still gets the grace-then-exit-0 path
SEQ="EMPTY"; run 0 30
grep -q "no checks reported after" <<<"$OUT" || fail "no checks: missing grace message"

# --- wait prints the head it saw, for merge to pin ---
SEQ="PASS"; run 0 30
grep -q "checks passed.* head=$HEAD_SHA" <<<"$OUT" || fail "wait did not print head=<sha> on pass"
SEQ="EMPTY"; run 0 30
grep -q "nothing to wait for head=$HEAD_SHA" <<<"$OUT" || fail "wait did not print head=<sha> on the no-checks path"

# --- merge ---
mrun() { # <expected-rc> <merge-args...>; leaves output in $OUT, gh pr merge argv log in $T/merge.log
  local want="$1" rc=0; shift
  : >"$GH_MERGE_LOG"
  OUT="$("$STEP" merge 7 "$@" 2>&1)" || rc=$?
  [ "$rc" -eq "$want" ] || fail "merge $* exited $rc, want $want"
}
unset GH_MERGE_RC GH_STATE_FAIL GH_STATE_OUT

mrun 0 "$HEAD_SHA"
grep -qx "pr merge 7 --merge --match-head-commit $HEAD_SHA" "$GH_MERGE_LOG" || fail "merge: explicit sha not passed via --match-head-commit"
grep -q "^MERGED abc1234$" <<<"$OUT" || fail "merge: missing 'MERGED <sha>' line"

mrun 0   # no sha: re-reads the current head and still pins it
grep -qx "pr merge 7 --merge --match-head-commit $HEAD_SHA" "$GH_MERGE_LOG" || fail "merge: head not read and pinned when no sha given"

mrun 2 "abc123"   # short sha is a usage error and merges nothing
[ ! -s "$GH_MERGE_LOG" ] || fail "merge ran gh pr merge despite a bad sha"

GH_MERGE_RC=1 mrun 1 "$HEAD_SHA"   # head moved / merge refused
grep -q "gh pr merge failed" <<<"$OUT" || fail "merge refusal: missing message"

# Finding: merge succeeded but the follow-up state read failed => distinct exit 5, clear message
GH_STATE_FAIL=1 mrun 5 "$HEAD_SHA"
grep -q "merged, but state check failed - verify with: gh pr view 7" <<<"$OUT" || fail "exit 5: missing verify message"
[ "$(wc -l <"$GH_MERGE_LOG")" -eq 1 ] || fail "exit 5: merge must not be retried"

GH_STATE_OUT="OPEN " mrun 1 "$HEAD_SHA"
grep -q "expected MERGED" <<<"$OUT" || fail "non-MERGED state: missing message"

# --- usage errors ---
OUT="$("$STEP" wait 2>&1)" && fail "wait with no PR should be a usage error"
OUT="$("$STEP" wait 7 abc 2>&1)" && fail "wait with a non-numeric cap should be a usage error"

echo "PASS"
