#!/usr/bin/env bash
# Self-contained test for `merge-step.sh wait`: a PATH-shimmed `gh` replays a scripted
# sequence of rollups/failures, so the CI-wait logic is exercised without GitHub.
# Covers: pass / red / pending->pass, persistent gh failure (exit 4, never "still pending"),
# transient gh failure recovery, cap hit while failing, an empty rollup after checks were
# seen (must not exit 0), and a repo that never reports any checks (exit 0 after the grace).
set -euo pipefail

STEP="$(cd "$(dirname "$0")" && pwd)/merge-step.sh"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT

# The shim reads its scenario from $GH_SEQ: one token per line, line N answers the Nth call,
# the last line repeats forever. Tokens: PENDING PASS RED EMPTY FAIL BLANK (blank = rc 0, no output).
mkdir "$T/bin"
cat >"$T/bin/gh" <<'GH'
#!/usr/bin/env bash
c=$(cat "$GH_COUNT" 2>/dev/null || echo 0); c=$((c + 1)); echo "$c" >"$GH_COUNT"
tok=$(sed -n "${c}p" "$GH_SEQ"); [ -n "$tok" ] || tok=$(tail -n 1 "$GH_SEQ")
case "$tok" in
  PENDING) echo '{"statusCheckRollup":[{"__typename":"CheckRun","name":"flake-check","status":"IN_PROGRESS","conclusion":""}]}' ;;
  PASS)    echo '{"statusCheckRollup":[{"__typename":"CheckRun","name":"flake-check","status":"COMPLETED","conclusion":"SUCCESS"}]}' ;;
  RED)     echo '{"statusCheckRollup":[{"__typename":"CheckRun","name":"flake-check","status":"COMPLETED","conclusion":"FAILURE"}]}' ;;
  EMPTY)   echo '{"statusCheckRollup":[]}' ;;
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

# --- usage errors ---
OUT="$("$STEP" wait 2>&1)" && fail "wait with no PR should be a usage error"
OUT="$("$STEP" wait 7 abc 2>&1)" && fail "wait with a non-numeric cap should be a usage error"

echo "PASS"
