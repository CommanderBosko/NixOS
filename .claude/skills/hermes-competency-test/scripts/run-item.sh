#!/usr/bin/env bash
# run-item.sh <run-root> <item-id> <repeat-number> [taker-override]
# One repeat of one item: reset the throwaway HERMES_HOME and the sandbox, run setup/truth, run the
# taker headless, tear down, then normalize, detect and check. Grading is a separate pass.
# Writes everything to <run-root>/items/<id>/r<N>/. Exit 0 = repeat completed (whatever the score);
# exit 1 = infrastructure error (also recorded in that repeat's error.txt).
set -uo pipefail
source "$(dirname "$0")/lib.sh"

RUN="${1:?run root}" ID="${2:?item id}" N="${3:?repeat}"
META="$RUN/meta.json"
TAKER="${4:-$(jq -r .taker "$META")}"
ITEM="$SKILL_DIR/items/$ID" KEY="$KEYS_DIR/$ID"
RD="$RUN/items/$ID/r$N"
TEST_HOME="$WORK_DIR/home"
HC_PY=(python3 -I "$SKILL_DIR/scripts/hc.py")

rm -rf "$RD"; mkdir -p "$RD/truth"
cp "$ITEM/item.json" "$RUN/items/$ID/item.json"
fail() { echo "$*" >"$RD/error.txt"; echo "error: $ID r$N: $*" >&2; exit 1; }

# kill_test_procs: stop Hermes processes (the on-demand gateway lingers) that run on the test home,
# and wait until they are gone (see stop_test_procs in lib.sh).
kill_test_procs() { stop_test_procs "$TEST_HOME"; }

guard_hashes() {  # outside-world guards, compared by hc.py detect
  hash_paths "$LIVE_HOME" "${LIVE_GUARD_PATHS[@]}" >"$RD/guard-home.$1" 2>/dev/null
  { git -C "$REPO_DIR" rev-parse HEAD; git -C "$REPO_DIR" status --porcelain; } >"$RD/guard-repo.$1" 2>/dev/null
  hash_paths "$KEYS_DIR" . >"$RD/guard-keys.$1" 2>/dev/null
}

mapfile -t PROTECTED < <(jq -r '.protected[]?' "$ITEM/item.json")
TIMEOUT=$(jq -r '.timeout_s // 900' "$ITEM/item.json")
CHECK_TIMEOUT=$(jq -r '.check_timeout_s // 120' "$ITEM/item.json")

# 1. Reset Hermes state and sandbox.
kill_test_procs || fail "Hermes processes on the test home survived SIGTERM and SIGKILL"
if [ "$TAKER" = hermes ]; then
  rsync -a --delete "$RUN/home-snapshot/" "$TEST_HOME/" || fail "home reset failed"
else
  rm -rf "$TEST_HOME"; mkdir -p "$TEST_HOME/memories"
fi
make_sandbox "$RUN/pristine.tar" "$SANDBOX_DIR" "$ID" "$REMOTE_DIR" >/dev/null 2>&1 || fail "sandbox build failed"
# Hermes sometimes writes task/out one level up (<work>/task) instead of in the sandbox; don't let
# that leak into the next repeat.
rm -rf "${WORK_DIR:?}/task"

export SANDBOX="$SANDBOX_DIR" RUN_DIR="$RD" ITEM_DIR="$ITEM" KEY_DIR="$KEY" HERMES_TEST_HOME="$TEST_HOME" TAKER

hash_paths "$SANDBOX_DIR" "${PROTECTED[@]}" >"$RD/protected.before"
guard_hashes before

# 2. Setup, then live ground truth (after setup, so planted faults are part of the truth).
if [ -x "$ITEM/setup.sh" ]; then
  (cd "$SANDBOX_DIR" && timeout 60 "$ITEM/setup.sh") >"$RD/setup.log" 2>&1 || fail "setup.sh failed (see setup.log)"
fi
if [ -x "$KEY/truth.sh" ]; then
  timeout 180 "$KEY/truth.sh" "$RD/truth" >"$RD/truth.log" 2>&1 || fail "truth.sh failed (see truth.log)"
fi

# 3. Run the taker.
start=$(date +%s.%N)
case "$TAKER" in
  hermes)
    # A chat that never got going (see startup_failed) means nothing ran, so try again (up to 3
    # attempts); if it never starts, record an infrastructure error (excluded from scores) instead of
    # grading a zero.
    for attempt in 1 2 3; do
      start=$(date +%s.%N)
      (cd "$SANDBOX_DIR" && HERMES_HOME="$TEST_HOME" timeout --kill-after=30 "$TIMEOUT" \
        hermes chat --query-file "$ITEM/prompt.md" --format stream-json) >"$RD/stream.jsonl" 2>"$RD/stderr.txt"
      rc=$?
      secs=$(awk -v s="$start" -v e="$(date +%s.%N)" 'BEGIN { print e - s }')
      startup_failed "$rc" "$secs" "$RD/stderr.txt" "$RD/stream.jsonl" || break
      echo "retry: $ID r$N attempt $attempt (rc=$rc, ${secs}s): $(startup_failure_reason "$RD/stderr.txt")" >&2
      [ "$attempt" -lt 3 ] || fail "hermes failed to start in 3 attempts: $(startup_failure_reason "$RD/stderr.txt")"
      kill_test_procs || fail "Hermes processes on the test home survived SIGTERM and SIGKILL"
      sleep "${HC_RETRY_SLEEP_S:-2}"
    done ;;
  claude)
    (cd "$SANDBOX_DIR" && env -u CLAUDECODE timeout --kill-after=30 "$TIMEOUT" \
      claude -p --model "$(jq -r '.calibration_model // "sonnet"' "$META")" \
        --output-format stream-json --verbose --permission-mode acceptEdits \
        --allowedTools "Bash Read Write Edit Glob Grep WebSearch WebFetch mcp__nixos__nix" \
        --disallowedTools "Agent" <"$ITEM/prompt.md") >"$RD/stream.jsonl" 2>"$RD/stderr.txt"
    rc=$? ;;
  fake)
    (cd "$SANDBOX_DIR" && "$SKILL_DIR/scripts/fake-taker.sh") >"$RD/stream.jsonl" 2>"$RD/stderr.txt"
    rc=$? ;;
  *) fail "unknown taker $TAKER" ;;
esac
end=$(date +%s.%N)
timed_out=false; [ "$rc" = 124 ] || [ "$rc" = 137 ] && timed_out=true
jq -n --argjson rc "$rc" --argjson to "$timed_out" --arg s "$start" --arg e "$end" \
  '{exit_code:$rc, timed_out:$to, duration_s:(($e|tonumber)-($s|tonumber)|.*10|round/10)}' >"$RD/exit.json"

# 4. Teardown, then stop anything left running.
if [ -x "$ITEM/teardown.sh" ]; then
  (cd "$SANDBOX_DIR" && timeout 60 "$ITEM/teardown.sh") >>"$RD/setup.log" 2>&1
fi
[ -f "$RD/pids" ] && xargs -r kill <"$RD/pids" 2>/dev/null
kill_test_procs

# 5. Capture what the agent produced.
hash_paths "$SANDBOX_DIR" "${PROTECTED[@]}" >"$RD/protected.after"
guard_hashes after
mkdir -p "$RD/out"
[ -d "$SANDBOX_DIR/task/out" ] && cp -a "$SANDBOX_DIR/task/out/." "$RD/out/"
git -C "$SANDBOX_DIR" add -A -N . 2>/dev/null
git -C "$SANDBOX_DIR" diff --stat >"$RD/sandbox.stat" 2>/dev/null
git -C "$SANDBOX_DIR" diff 2>/dev/null | head -c 200000 >"$RD/sandbox.diff"

# 6. Normalize, detect, check.
"${HC_PY[@]}" normalize "$RD" "$TAKER" || fail "normalize failed"
"${HC_PY[@]}" detect "$RD" "$SANDBOX_DIR" >/dev/null || fail "detect failed"
if [ -x "$KEY/check.sh" ]; then
  if timeout "$CHECK_TIMEOUT" "$KEY/check.sh" >"$RD/check.out" 2>"$RD/check.err" && jq -e 'type=="object"' "$RD/check.out" >/dev/null 2>&1; then
    mv "$RD/check.out" "$RD/check.json"
  else
    echo "check.sh failed or printed invalid JSON" >"$RD/check.failed"
  fi
fi
echo "done $ID r$N exit=$rc timed_out=$timed_out"
