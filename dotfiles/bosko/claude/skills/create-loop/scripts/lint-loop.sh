#!/usr/bin/env bash
# Mechanical structural lint for a generated loop SKILL.md, matching the
# contract in assets/loop-template.md. Judgment checks (are the done-rules
# actually measurable, does a verification pass resolve) stay in create-loop's
# own Step 4 prose — this script only checks presence/shape, never meaning.
#
# Usage: lint-loop.sh <path-to-SKILL.md>
set -uo pipefail

FILE="${1:-}"
if [ -z "$FILE" ]; then
  echo "usage: lint-loop.sh <path-to-SKILL.md>" >&2
  exit 1
fi

if [ ! -f "$FILE" ]; then
  echo "FAIL: file does not exist: $FILE"
  exit 1
fi

FAILED=0
check() {
  local desc="$1" pattern="$2"
  if grep -qE -- "$pattern" "$FILE"; then
    echo "PASS: $desc"
  else
    echo "FAIL: $desc"
    FAILED=1
  fi
}

# Frontmatter: name:/description: between the opening/closing --- lines.
FRONTMATTER="$(sed -n '/^---$/,/^---$/p' "$FILE" | head -n -1 | tail -n +2)"
if echo "$FRONTMATTER" | grep -q '^name:' && echo "$FRONTMATTER" | grep -q '^description:'; then
  echo "PASS: frontmatter has name:/description:"
else
  echo "FAIL: frontmatter has name:/description:"
  FAILED=1
fi

# name: must equal the parent directory name, or the slash command won't resolve.
DIRNAME="$(basename "$(dirname "$FILE")")"
FM_NAME="$(echo "$FRONTMATTER" | sed -n 's/^name: *//p' | head -1)"
if [ "$FM_NAME" = "$DIRNAME" ]; then
  echo "PASS: name: ($FM_NAME) matches directory ($DIRNAME)"
else
  echo "FAIL: name: ($FM_NAME) does not match directory ($DIRNAME)"
  FAILED=1
fi

check "Training Mode block present"      'Loop Training Mode: \*\*(ON|OFF)\*\*'
check "Retry cap stated"                 '\*\*Retry cap:\*\*'
check "Goal section present"             '^## Goal'
check "Overall done-rule section present" '^## Overall done-rule'
check "Steps section present"            '^## Steps'
check "at least one step Done-rule"      '- Done-rule:'
check "Verification plan section present" '^## Verification plan'
check "dual-file output section present" '^## End-of-run: write two files \(ALWAYS\)'
check "Output file line present"         '\*\*Output\*\*'
check "Memory file line present"         '\*\*Memory\*\*'
check "Report section present"           '^## Report'

if [ "$FAILED" -eq 0 ]; then
  echo "RESULT: PASS — structurally well-formed"
  exit 0
else
  echo "RESULT: FAIL — see FAIL lines above"
  exit 1
fi
