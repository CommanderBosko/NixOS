#!/usr/bin/env bash
# Scan this project's Claude Code session transcripts for tool errors and report
# which Skill was active when each one happened, so skill-upgrade can spot
# misfires that recur across sessions (not just within the current one).
#
# Usage: find-skill-misfires.sh [project-dir] [max-files] [since-timestamp]
#   project-dir      defaults to $PWD
#   max-files        most-recently-modified transcripts to scan when
#                     since-timestamp is not given (default 15)
#   since-timestamp  ISO-8601 cutoff (e.g. from find-last-skill-invocation.sh).
#                     When given, scans every transcript touched at or after
#                     that time instead of an arbitrary recent-N window --
#                     pass skill-upgrade's own last-invocation timestamp here
#                     to review "since I last ran" rather than a fixed count.

set -euo pipefail

PROJECT_DIR="${1:-$PWD}"
MAX_FILES="${2:-15}"
SINCE="${3:-}"

LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../lib" && pwd)"
TRANSCRIPT_DIR="$("$LIB_DIR/find-transcript-dir.sh" "$PROJECT_DIR")" || exit 1

if [ -n "$SINCE" ]; then
  FILES=$("$LIB_DIR/list-transcripts-since.sh" "$SINCE" "$PROJECT_DIR")
else
  FILES=$(cd "$TRANSCRIPT_DIR" && ls -t -- *.jsonl 2>/dev/null | head -n "$MAX_FILES")
fi

if [ -z "$FILES" ]; then
  echo "No .jsonl transcripts found in $TRANSCRIPT_DIR" >&2
  exit 1
fi

cd "$TRANSCRIPT_DIR"
python3 - "$FILES" <<'PYEOF'
import json, re, sys

files = sys.argv[1].split("\n")
# A user-typed slash command (e.g. `/skill-audit`) is injected by Claude Code
# as plain user-turn string content, not an assistant `Skill` tool_use -- so
# current_skill tracking must also catch this, or every misfire that happens
# during a slash-command-invoked skill gets mis-attributed to whatever skill
# (or None) was active before it. Mirrors find-last-skill-invocation.sh's
# already-fixed detection, generalized to capture whichever skill name
# matched rather than checking against one fixed name.
slash_re = re.compile(r"<command-name>/([a-zA-Z0-9_-]+)</command-name>")

for fn in files:
    fn = fn.strip()
    if not fn:
        continue
    tool_uses = {}
    current_skill = None
    hits = []
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
                if isinstance(content, str):
                    m = slash_re.search(content)
                    if m:
                        current_skill = m.group(1)
                    continue
                if not isinstance(content, list):
                    continue
                for c in content:
                    if not isinstance(c, dict):
                        continue
                    if c.get("type") == "tool_use":
                        tool_uses[c.get("id")] = (c.get("name"), c.get("input"))
                        if c.get("name") == "Skill":
                            current_skill = c.get("input", {}).get("skill")
                    elif c.get("type") == "tool_result" and c.get("is_error"):
                        name, inp = tool_uses.get(c.get("tool_use_id"), ("?", {}))
                        err = c.get("content")
                        if isinstance(err, list):
                            err = " ".join(str(x.get("text", "")) for x in err if isinstance(x, dict))
                        hits.append((current_skill, name, str(inp)[:150], str(err)[:200]))
    except OSError:
        continue
    if hits:
        print(f"=== {fn} ===")
        for skill_ctx, tool, inp, err in hits:
            print(f"  skill={skill_ctx} tool={tool} input={inp} err={err}")
PYEOF
