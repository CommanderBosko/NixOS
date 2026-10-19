#!/usr/bin/env bash
# Steps 1-2 of refresh-manager-profile: enumerate every known project and list
# the transcripts with activity since this skill's last run for that project.
#
# Usage: list-new-activity.sh [full [<project-path>]]
#   (no args)             incremental scan, every project
#   full                  full re-mine, every project (empty cutoff)
#   full <project-path>   full re-mine for that one project only; others stay incremental
#
# Output, per project with new transcripts:
#   PROJECT<TAB><real-project-path><TAB><cutoff-or-empty>
#   FILE<TAB><transcript-filename>      (one line per file, newest first)
# Prints nothing if no project has new activity.
set -uo pipefail

MODE="${1:-}"
ONLY="${2:-}"
LIB="$HOME/.claude/skills/lib"

# Same filter as lib/list-transcripts-since.sh, but on the transcript dir
# list-all-projects.sh already resolved -- re-deriving it from the real path
# can land on a different dir (renamed projects, slug-formula drift).
list_since() {  # <cutoff-or-empty> <transcript-dir>
  ( cd "$2" 2>/dev/null || exit 1
    FILES=$(ls -t -- *.jsonl 2>/dev/null)
    [ -z "$FILES" ] && exit 0
    [ -z "$1" ] && { printf '%s\n' "$FILES"; exit 0; }
    python3 - "$1" $FILES <<'PYEOF'
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
  )
}

"$LIB/list-all-projects.sh" | while IFS=$'\t' read -r proj tdir; do
  [ -z "$proj" ] || [ "$proj" = "UNKNOWN" ] && continue
  if [ "$MODE" = "full" ] && { [ -z "$ONLY" ] || [ "$ONLY" = "$proj" ]; }; then
    cutoff=""
  else
    cutoff=$("$LIB/find-last-skill-invocation.sh" refresh-manager-profile "$proj" 2>/dev/null || true)
  fi
  files=$(list_since "$cutoff" "$tdir" 2>/dev/null || true)
  [ -z "$files" ] && continue
  printf 'PROJECT\t%s\t%s\n' "$proj" "$cutoff"
  printf '%s\n' "$files" | sed 's/^/FILE\t/'
done
