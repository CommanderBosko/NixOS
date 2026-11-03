#!/usr/bin/env bash
# Tests for find-skill-misfires.sh skill attribution (stale-skill latch, /clear,
# built-in slash commands). Builds a synthetic transcript under a throwaway
# $HOME so nothing real is read. Run: bash find-skill-misfires.test.sh
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$HERE/find-skill-misfires.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

export HOME="$TMP/home"
PROJ="$TMP/proj"
SLUG="$(echo "$PROJ" | sed 's#/#-#g')"
TDIR="$HOME/.claude/projects/$SLUG"
mkdir -p "$TDIR" "$HOME/.claude/skills/alpha" "$HOME/.claude/skills/beta" "$PROJ"
# find-skill-misfires.sh sources its lib dir relative to itself, so run the real one.

python3 -I - "$TDIR/t.jsonl" <<'EOF'
import json, sys

out = []
n = [0]

def tid():
    n[0] += 1
    return f"toolu_{n[0]}"

def user_text(text):
    out.append({"type": "user", "message": {"role": "user", "content": text}})

def user_blocks(text):
    out.append({"type": "user", "message": {"role": "user", "content": [{"type": "text", "text": text}]}})

def slash(name):
    user_text(f"<command-message>{name}</command-message>\n<command-name>/{name}</command-name>")

def skill_call(name):
    out.append({"type": "assistant", "message": {"role": "assistant", "content": [
        {"type": "tool_use", "id": tid(), "name": "Skill", "input": {"skill": name}}]}})

def failing_bash(cmd):
    i = tid()
    out.append({"type": "assistant", "message": {"role": "assistant", "content": [
        {"type": "tool_use", "id": i, "name": "Bash", "input": {"command": cmd}}]}})
    out.append({"type": "user", "message": {"role": "user", "content": [
        {"type": "tool_result", "tool_use_id": i, "is_error": True, "content": "boom " + cmd}]}})

# 1. fresh Skill tool_use, error in the same turn -> attributed, not stale
skill_call("alpha")
failing_bash("case1")
# 2. tool results and system reminders are not user turns
out.append({"type": "user", "message": {"role": "user", "content": [{"type": "text", "text": "<system-reminder>x</system-reminder>"}]}})
failing_bash("case2")
# 3. two real user prompts later -> still alpha, but stale_turns=2
user_text("thanks, now something else")
user_blocks("and another thing")
failing_bash("case3")
# 4. /clear resets attribution to None
slash("clear")
failing_bash("case4")
# 5. slash command that IS a skill in the roster -> attributed, fresh
slash("beta")
failing_bash("case5")
# 6. built-in /compact is ignored: beta stays active
slash("compact")
failing_bash("case6")
# 7. built-in command that is not a skill and no prior skill -> still the old skill, never 'compact'
slash("model")
failing_bash("case7")

with open(sys.argv[1], "w") as f:
    for o in out:
        f.write(json.dumps(o) + "\n")
EOF

OUT="$(bash "$SCRIPT" "$PROJ" 5 2>&1)"
rc=$?
pass=0
fail=0

check() { # <description> <fixed-string-that-must-appear-on-one-line> [must-not-match-regex]
  local desc="$1" want="$2"
  if grep -qF -- "$want" <<<"$OUT"; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
    echo "FAIL: $desc -- expected a line containing: $want"
  fi
}

[ "$rc" -eq 0 ] && pass=$((pass + 1)) || { fail=$((fail + 1)); echo "FAIL: script exit $rc"; }
check "fresh Skill call is attributed with no stale marker" "skill=alpha tool=Bash input={'command': 'case1'}"
check "system-reminder text is not a user turn" "skill=alpha tool=Bash input={'command': 'case2'}"
check "two user prompts later is flagged stale_turns=2" "skill=alpha stale_turns=2 tool=Bash input={'command': 'case3'}"
check "/clear resets attribution" "skill=None tool=Bash input={'command': 'case4'}"
check "slash-invoked roster skill is attributed" "skill=beta tool=Bash input={'command': 'case5'}"
check "built-in /compact does not replace the active skill" "skill=beta tool=Bash input={'command': 'case6'}"
check "built-in /model does not replace the active skill" "skill=beta tool=Bash input={'command': 'case7'}"

for bad in "skill=clear" "skill=compact" "skill=model"; do
  if grep -qF -- "$bad" <<<"$OUT"; then
    fail=$((fail + 1))
    echo "FAIL: built-in command was recorded as a skill ($bad)"
  else
    pass=$((pass + 1))
  fi
done

echo "find-skill-misfires.test.sh: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
