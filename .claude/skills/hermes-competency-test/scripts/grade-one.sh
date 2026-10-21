#!/usr/bin/env bash
# grade-one.sh <repeat-dir>: grade one repeat (items/<id>/r<N>) with hc.py; infra errors become a
# zero-score grade.json carrying the error so scoring can exclude them.
set -uo pipefail
source "$(dirname "$0")/lib.sh"
rd="$1" id=$(basename "$(dirname "$1")")
if [ -f "$rd/error.txt" ]; then
  jq -n --arg e "$(cat "$rd/error.txt")" '{score:0, error:$e, critical:[], void:false, judge:[], check:[]}' >"$rd/grade.json"
  exit 0
fi
python3 -I "$SKILL_DIR/scripts/hc.py" grade "$rd" "$SKILL_DIR/items/$id" "$KEYS_DIR/$id" \
  --model "${HC_GRADER_MODEL:-sonnet}" >>"$rd/grade.log" 2>&1
