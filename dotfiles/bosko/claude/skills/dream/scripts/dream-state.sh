#!/usr/bin/env bash
# Deterministic run-log + overview-file mechanics for the `dream` orchestrator.
# Keeps JSON read-modify-write in one place instead of asking the model to
# hand-edit run-log.json (error-prone) or re-derive Status-line parsing in
# prose each run.
#
# Usage:
#   dream-state.sh init
#     Ensures ~/.claude/dream/ and run-log.json exist. Prints the run-log path.
#   dream-state.sh get
#     Prints the current run-log.json contents (creates it first if absent).
#   dream-state.sh latest-overview
#     Prints the path to the most recent ~/.claude/dream/overview-*.md file
#     (filename timestamps sort lexicographically), or nothing if none exist.
#   dream-state.sh overview-status <overview-file>
#     Prints just the Status value from a given overview file (PENDING_REVIEW
#     / APPROVED / REJECTED / APPLIED), or "MISSING" if it has no Status:
#     line at all.
#   dream-state.sh record-full-run <analysis-file> <overview-file>
#     Records a completed session-analysis+improve-memory pass.
#   dream-state.sh record-apply <overview-file> <result>
#     Records a completed apply pass (result: "applied" or a "skipped: <why>"
#     string). When result is exactly "applied", also rewrites the overview
#     file's own Status: line to APPLIED -- a skip leaves it untouched.
set -uo pipefail

DREAM_DIR="$HOME/.claude/dream"
RUN_LOG="$DREAM_DIR/run-log.json"
CMD="${1:?usage: dream-state.sh <init|get|latest-overview|overview-status|record-full-run|record-apply> [...]}"
shift || true

mkdir -p "$DREAM_DIR"

init_run_log() {
  if [ ! -f "$RUN_LOG" ]; then
    python3 - "$RUN_LOG" <<'PYEOF'
import json, sys
path = sys.argv[1]
skeleton = {
    "last_overview_file": None,
    "last_overview_status_seen": None,
    "last_full_run_at": None,
    "last_apply_at": None,
    "history": [],
}
with open(path, "w") as f:
    json.dump(skeleton, f, indent=2)
    f.write("\n")
PYEOF
  fi
}

case "$CMD" in
  init)
    init_run_log
    echo "$RUN_LOG"
    ;;

  get)
    init_run_log
    cat "$RUN_LOG"
    ;;

  latest-overview)
    shopt -s nullglob
    files=("$DREAM_DIR"/overview-*.md)
    shopt -u nullglob
    if [ "${#files[@]}" -gt 0 ]; then
      printf '%s\n' "${files[@]}" | sort | tail -1
    fi
    ;;

  overview-status)
    FILE="${1:?usage: dream-state.sh overview-status <overview-file>}"
    line="$(grep -m1 '^Status:' "$FILE" 2>/dev/null || true)"
    if [ -z "$line" ]; then
      echo "MISSING"
    else
      echo "$line" | sed -E 's/^Status:[[:space:]]*//'
    fi
    ;;

  record-full-run)
    ANALYSIS_FILE="${1:?usage: dream-state.sh record-full-run <analysis-file> <overview-file>}"
    OVERVIEW_FILE="${2:?usage: dream-state.sh record-full-run <analysis-file> <overview-file>}"
    init_run_log
    python3 - "$RUN_LOG" "$ANALYSIS_FILE" "$OVERVIEW_FILE" <<'PYEOF'
import json, sys, datetime
path, analysis_file, overview_file = sys.argv[1], sys.argv[2], sys.argv[3]
with open(path) as f:
    log = json.load(f)
now = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
log["last_overview_file"] = overview_file
log["last_overview_status_seen"] = "PENDING_REVIEW"
log["last_full_run_at"] = now
log.setdefault("history", []).append({
    "timestamp": now,
    "action": "full_run",
    "analysis_file": analysis_file,
    "overview_file": overview_file,
})
with open(path, "w") as f:
    json.dump(log, f, indent=2)
    f.write("\n")
PYEOF
    ;;

  record-apply)
    OVERVIEW_FILE="${1:?usage: dream-state.sh record-apply <overview-file> <result>}"
    RESULT="${2:?usage: dream-state.sh record-apply <overview-file> <result>}"
    init_run_log
    python3 - "$RUN_LOG" "$OVERVIEW_FILE" "$RESULT" <<'PYEOF'
import json, sys, datetime
path, overview_file, result = sys.argv[1], sys.argv[2], sys.argv[3]
with open(path) as f:
    log = json.load(f)
now = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
log["last_apply_at"] = now
if result == "applied":
    log["last_overview_status_seen"] = "APPLIED"
log.setdefault("history", []).append({
    "timestamp": now,
    "action": "apply_fixes",
    "overview_file": overview_file,
    "result": result,
})
with open(path, "w") as f:
    json.dump(log, f, indent=2)
    f.write("\n")
PYEOF
    if [ "$RESULT" = "applied" ]; then
      python3 - "$OVERVIEW_FILE" <<'PYEOF'
import re, sys
path = sys.argv[1]
with open(path) as f:
    content = f.read()
content = re.sub(r"^Status:.*$", "Status: APPLIED", content, count=1, flags=re.MULTILINE)
with open(path, "w") as f:
    f.write(content)
PYEOF
    fi
    ;;

  *)
    echo "Unknown subcommand: $CMD" >&2
    exit 2
    ;;
esac
