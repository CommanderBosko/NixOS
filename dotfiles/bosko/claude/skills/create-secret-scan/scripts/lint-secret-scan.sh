#!/usr/bin/env bash
# Mechanical structural lint for a generated project-local secret-scan skill, matching
# the contract in assets/secret-scan-template.md + assets/secret-scan-script-template.sh.
# Judgment checks (are the interview answers actually accurate for this project, does a
# real scan run resolve) stay in create-secret-scan's own Step 4 prose — this script only
# checks presence/shape, never meaning.
#
# Usage: lint-secret-scan.sh <path-to-skill-dir>   (the dir containing SKILL.md)
set -uo pipefail

DIR="${1:-}"
if [ -z "$DIR" ]; then
  echo "usage: lint-secret-scan.sh <path-to-skill-dir>" >&2
  exit 1
fi

FILE="$DIR/SKILL.md"
SCRIPT="$DIR/scripts/secret-scan.sh"

if [ ! -f "$FILE" ]; then
  echo "FAIL: SKILL.md does not exist: $FILE"
  exit 1
fi

FAILED=0
check() {
  local desc="$1" pattern="$2" target="${3:-$FILE}"
  if grep -qE -- "$pattern" "$target"; then
    echo "PASS: $desc"
  else
    echo "FAIL: $desc"
    FAILED=1
  fi
}

FRONTMATTER="$(sed -n '/^---$/,/^---$/p' "$FILE" | head -n -1 | tail -n +2)"
if echo "$FRONTMATTER" | grep -q '^name:' && echo "$FRONTMATTER" | grep -q '^description:'; then
  echo "PASS: frontmatter has name:/description:"
else
  echo "FAIL: frontmatter has name:/description:"
  FAILED=1
fi

DIRNAME="$(basename "$DIR")"
FM_NAME="$(echo "$FRONTMATTER" | sed -n 's/^name: *//p' | head -1)"
if [ "$FM_NAME" = "$DIRNAME" ]; then
  echo "PASS: name: ($FM_NAME) matches directory ($DIRNAME)"
else
  echo "FAIL: name: ($FM_NAME) does not match directory ($DIRNAME)"
  FAILED=1
fi

check "model: haiku pinned"                 '^model: haiku'
check "What it knows about this project section" '^## What it knows about this project'
check "Instructions section present"        '^## Instructions'
check "Notes section present"               '^## Notes'
check "Script section present"              '^## Script'

if grep -qE '<[A-Z_]+>' "$FILE"; then
  echo "FAIL: unfilled <PLACEHOLDER> tokens remain in SKILL.md"
  FAILED=1
else
  echo "PASS: no unfilled <PLACEHOLDER> tokens in SKILL.md"
fi

if [ ! -f "$SCRIPT" ]; then
  echo "FAIL: scripts/secret-scan.sh does not exist: $SCRIPT"
  FAILED=1
else
  echo "PASS: scripts/secret-scan.sh exists"
  if [ -x "$SCRIPT" ]; then
    echo "PASS: scripts/secret-scan.sh is executable"
  else
    echo "FAIL: scripts/secret-scan.sh is not executable (chmod +x)"
    FAILED=1
  fi
  if grep -qE '<[A-Z_]+>' "$SCRIPT"; then
    echo "FAIL: unfilled <PLACEHOLDER> tokens remain in scripts/secret-scan.sh"
    FAILED=1
  else
    echo "PASS: no unfilled <PLACEHOLDER> tokens in scripts/secret-scan.sh"
  fi
  if bash -n "$SCRIPT" 2>/dev/null; then
    echo "PASS: scripts/secret-scan.sh is syntactically valid bash"
  else
    echo "FAIL: scripts/secret-scan.sh has a bash syntax error"
    FAILED=1
  fi
fi

if [ "$FAILED" -eq 0 ]; then
  echo "RESULT: PASS — structurally well-formed"
  exit 0
else
  echo "RESULT: FAIL — see FAIL lines above"
  exit 1
fi
