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
#
# Output: one `skill=<name> [stale_turns=N] tool=... input=... err=...` line
# per tool error. The skill attribution is "the last skill invoked before this
# error", so it can outlive the skill's real work: `stale_turns=N` counts the
# user-typed prompts since that invocation (absent when 0). A hit with
# stale_turns>=1 may belong to unrelated work after the skill finished --
# check the tool/input before blaming the skill. `/clear` resets the
# attribution to None; slash commands that are not skills (e.g. /compact,
# /model) are ignored rather than recorded as the active skill.

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
  # Nothing new since the cutoff is a valid "nothing to review" result, not an error.
  if [ -n "$SINCE" ]; then
    echo "no transcripts since $SINCE"
    exit 0
  fi
  echo "No .jsonl transcripts found in $TRANSCRIPT_DIR" >&2
  exit 1
fi

# Names of real skills (global + this project's), so a typed slash command is only
# attributed when it is actually a skill. Built-ins like /clear and /compact are not.
ROSTER=""
for d in "$HOME"/.claude/skills/*/ "$PROJECT_DIR"/.claude/skills/*/; do
  [ -d "$d" ] && ROSTER+="$(basename "$d")"$'\n'
done
export MISFIRE_SKILL_ROSTER="$ROSTER"

cd "$TRANSCRIPT_DIR"
python3 - "$FILES" <<'PYEOF'
import json, os, re, sys

files = sys.argv[1].split("\n")
# A user-typed slash command (e.g. `/skill-audit`) is injected by Claude Code
# as plain user-turn string content, not an assistant `Skill` tool_use -- so
# current_skill tracking must also catch this, or every misfire that happens
# during a slash-command-invoked skill gets mis-attributed to whatever skill
# (or None) was active before it. Mirrors find-last-skill-invocation.sh's
# already-fixed detection, generalized to capture whichever skill name
# matched rather than checking against one fixed name.
slash_re = re.compile(r"<command-name>/([a-zA-Z0-9_-]+)</command-name>")
roster = set(filter(None, os.environ.get("MISFIRE_SKILL_ROSTER", "").split("\n")))


def is_user_prompt(obj, content):
    """A genuine user-typed prompt: not a tool result, slash-command wrapper or system reminder."""
    if obj.get("type") != "user" or obj.get("isMeta"):
        return False
    if isinstance(content, str):
        text = content.lstrip()
        return bool(text) and not text.startswith(("<command-", "<local-command", "<system-reminder"))
    if isinstance(content, list):
        if any(isinstance(c, dict) and c.get("type") == "tool_result" for c in content):
            return False
        for c in content:
            if isinstance(c, dict) and c.get("type") == "text":
                text = (c.get("text") or "").lstrip()
                if text and not text.startswith("<system-reminder"):
                    return True
    return False


for fn in files:
    fn = fn.strip()
    if not fn:
        continue
    tool_uses = {}
    current_skill = None
    user_turns = 0   # genuine user prompts seen so far in this transcript
    skill_turn = 0   # value of user_turns when current_skill was set
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
                if is_user_prompt(obj, content):
                    user_turns += 1
                if isinstance(content, str):
                    m = slash_re.search(content)
                    if m:
                        name = m.group(1)
                        if name == "clear":
                            current_skill = None  # context wiped; nothing is active
                        elif name in roster:
                            current_skill, skill_turn = name, user_turns
                        # any other name is a built-in command, not a skill: ignore it
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
                            skill_turn = user_turns
                    elif c.get("type") == "tool_result" and c.get("is_error"):
                        name, inp = tool_uses.get(c.get("tool_use_id"), ("?", {}))
                        err = c.get("content")
                        if isinstance(err, list):
                            err = " ".join(str(x.get("text", "")) for x in err if isinstance(x, dict))
                        hits.append((current_skill, user_turns - skill_turn, name, str(inp)[:150], str(err)[:200]))
    except OSError:
        continue
    if hits:
        print(f"=== {fn} ===")
        for skill_ctx, stale, tool, inp, err in hits:
            stale_s = f" stale_turns={stale}" if skill_ctx is not None and stale > 0 else ""
            print(f"  skill={skill_ctx}{stale_s} tool={tool} input={inp} err={err}")
PYEOF
