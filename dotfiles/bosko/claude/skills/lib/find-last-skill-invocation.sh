#!/usr/bin/env bash
# Finds when a given skill was last invoked, prior to the current call, by
# scanning this project's Claude Code session transcripts for `Skill`
# tool_use entries whose input.skill matches. Shared by skill-suggestion,
# skill-upgrade, and skill-audit so each can scope its own log review to
# "what's happened since I last ran" instead of an arbitrary recent-N-files
# window.
#
# Usage: find-last-skill-invocation.sh <skill-name> [project-dir]
#   skill-name   the `skill` value passed to the Skill tool (e.g. skill-audit)
#   project-dir  defaults to $PWD
#
# Prints the ISO-8601 timestamp of the invocation before the current one on
# stdout. Prints nothing (exit 0) if this is the first-ever invocation of
# that skill for this project -- callers should treat that as "scan full
# history", not as an error.
set -uo pipefail

SKILL_NAME="${1:?usage: find-last-skill-invocation.sh <skill-name> [project-dir]}"
PROJECT_DIR="${2:-$PWD}"

LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TRANSCRIPT_DIR="$("$LIB_DIR/find-transcript-dir.sh" "$PROJECT_DIR" 2>/dev/null)" || exit 0

FILES=$(cd "$TRANSCRIPT_DIR" && ls -- *.jsonl 2>/dev/null)
[ -z "$FILES" ] && exit 0

cd "$TRANSCRIPT_DIR"
python3 - "$SKILL_NAME" $FILES <<'PYEOF'
import json, sys

skill_name = sys.argv[1]
files = sys.argv[2:]

timestamps = []
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
                content = obj.get("message", {}).get("content")
                if not isinstance(content, list):
                    continue
                for c in content:
                    if (
                        isinstance(c, dict)
                        and c.get("type") == "tool_use"
                        and c.get("name") == "Skill"
                        and c.get("input", {}).get("skill") == skill_name
                    ):
                        ts = obj.get("timestamp")
                        if ts:
                            timestamps.append(ts)
    except OSError:
        continue

timestamps.sort(reverse=True)
# timestamps[0] is the current invocation (already logged by the time this
# runs); the one we want is the previous one, timestamps[1].
if len(timestamps) >= 2:
    print(timestamps[1])
PYEOF
