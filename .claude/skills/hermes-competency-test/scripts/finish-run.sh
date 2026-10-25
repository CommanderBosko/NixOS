#!/usr/bin/env bash
# finish-run.sh <run-root> [pass|fail|skipped|not_offered]
# Records the supervised network stage outcome, re-scores the run and appends it to history.jsonl
# (once), unless the run is partial (exit 3). Prints the report path. Run after Claude has decided on the supervised stage.
set -euo pipefail
source "$(dirname "$0")/lib.sh"
RUN="${1:?run root}" SUP="${2:-}"
if [ -n "$SUP" ]; then
  jq --arg s "$SUP" '.supervised_net = $s' "$RUN/meta.json" >"$RUN/meta.tmp" && mv "$RUN/meta.tmp" "$RUN/meta.json"
fi
if [ "$(jq -r '.history_appended // false' "$RUN/meta.json")" = true ]; then
  python3 -I "$SKILL_DIR/scripts/hc.py" score "$RUN" >/dev/null
  echo "history already has this run; re-scored only" >&2
elif python3 -I "$SKILL_DIR/scripts/hc.py" score "$RUN" >/dev/null \
     && [ "$(jq -r '.partial // false' "$RUN/summary.json")" = true ] && [ "${HC_ALLOW_PARTIAL:-0}" != 1 ]; then
  # A run with excluded or unscored items would put a skewed number in the history and the noise floor.
  echo "run is partial, so it was re-scored but NOT added to history (set HC_ALLOW_PARTIAL=1 to force):" >&2
  jq -r '.warnings[] | "  - " + .' "$RUN/summary.json" >&2
  echo "$RUN/report.md"
  exit 3
else
  python3 -I "$SKILL_DIR/scripts/hc.py" score "$RUN" --append-history >/dev/null
  jq '.history_appended = true' "$RUN/meta.json" >"$RUN/meta.tmp" && mv "$RUN/meta.tmp" "$RUN/meta.json"
fi
echo "$RUN/report.md"
