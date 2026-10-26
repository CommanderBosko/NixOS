#!/usr/bin/env bash
# preflight.sh <run-root>: two back-to-back real Hermes chats (the canary item's trivial prompt, repeats
# r2 and r3; r1 is the fake-taker detector canary). The fake canary never touches Hermes, so without
# this a broken gateway start or a slow drain between repeats only shows up hours into a run.
# Exit 0 = both chats ran cleanly and produced a parseable stream (a tool event or an answer);
# 1 = one failed or parsed to nothing (the reason is the last line on stdout).
set -uo pipefail
source "$(dirname "$0")/lib.sh"
RUN="${1:?run root}"

for r in 2 3; do
  rd="$RUN/items/canary/r$r"
  "$SKILL_DIR/scripts/run-item.sh" "$RUN" canary "$r" hermes >/dev/null 2>"$RUN/preflight-r$r.err"
  rc=$?
  code=$(jq -r '.exit_code // "none"' "$rd/exit.json" 2>/dev/null || echo none)
  if [ "$rc" -ne 0 ] || [ "$code" != 0 ]; then
    reason=$(cat "$rd/error.txt" 2>/dev/null) || reason=$(startup_failure_reason "$rd/stderr.txt")
    echo "canary r$r on real hermes failed (run-item rc=$rc, hermes exit=$code): ${reason:-no output}"
    exit 1
  fi
  # A clean exit isn't proof the chat ran: if the stream parsed to nothing (no tool event, no answer text)
  # the run would be graded on empty output, so that is a harness failure, not a pass.
  nev=$(jq 'length' "$rd/events.json" 2>/dev/null || echo 0)
  if [ "${nev:-0}" -eq 0 ] && ! grep -q '[^[:space:]]' "$rd/final.txt" 2>/dev/null; then
    echo "canary r$r on real hermes parsed to nothing (hermes exit=$code, $(wc -c <"$rd/stream.jsonl" 2>/dev/null || echo 0) bytes of stream, 0 tool events, empty answer): $(startup_failure_reason "$rd/stderr.txt")"
    exit 1
  fi
done
echo "2 back-to-back hermes chats started and finished cleanly"
