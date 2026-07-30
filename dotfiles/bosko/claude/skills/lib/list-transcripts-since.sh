#!/usr/bin/env bash
# Lists which of this project's Claude Code session transcripts contain any
# entry at or after a given cutoff timestamp. Pairs with
# find-last-skill-invocation.sh: pass its output straight through as the
# cutoff to scope a log review to "since I last ran".
#
# Usage: list-transcripts-since.sh [cutoff-iso-timestamp] [project-dir]
#   cutoff-iso-timestamp  ISO-8601 timestamp, or "" / omitted to mean "no
#                         prior invocation" -- in that case ALL transcripts
#                         are printed (full history).
#   project-dir           defaults to $PWD
#
# Prints matching filenames (relative to the transcript dir), one per line,
# newest first.
set -uo pipefail

CUTOFF="${1:-}"
PROJECT_DIR="${2:-$PWD}"

LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TRANSCRIPT_DIR="$("$LIB_DIR/find-transcript-dir.sh" "$PROJECT_DIR" 2>/dev/null)" || exit 1

cd "$TRANSCRIPT_DIR"
FILES=$(ls -t -- *.jsonl 2>/dev/null)
[ -z "$FILES" ] && exit 0

if [ -z "$CUTOFF" ]; then
  printf '%s\n' "$FILES"
  exit 0
fi

python3 - "$CUTOFF" $FILES <<'PYEOF'
import json, sys

cutoff = sys.argv[1]
files = sys.argv[2:]

for fn in files:
    try:
        with open(fn) as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    obj = json.loads(line)
                except (ValueError, json.JSONDecodeError):
                    continue
                ts = obj.get("timestamp")
                if ts and ts >= cutoff:
                    print(fn)
                    break
    except OSError:
        continue
PYEOF
