#!/usr/bin/env bash
# Mechanical heading-presence check for the standing rules against a
# CLAUDE.md file. Prints "present" or "missing" per rule; does not edit
# anything. Judgment calls (ambiguous/variant headings) stay in the SKILL.
#
# The rule roster is not typed here: it is every `## ` heading in
# assets/rules.md that sits outside a ``` fence. A heading's trailing
# "(...)" is dropped for matching, so "## Scope First (Interview)" in
# rules.md matches any CLAUDE.md heading starting "## Scope First"
# (case-insensitive).
# Usage: check-rules.sh <path-to-CLAUDE.md>
set -euo pipefail

FILE="${1:?usage: check-rules.sh <path-to-CLAUDE.md>}"
SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RULES_MD="$SKILL_DIR/assets/rules.md"

if [ ! -f "$RULES_MD" ]; then
  echo "ERROR: rules file not found: $RULES_MD" >&2
  exit 2
fi

mapfile -t RULES < <(awk '
  /^```/ { fence = !fence; next }
  !fence && /^## / { sub(/^## +/, ""); sub(/ +$/, ""); print }
' "$RULES_MD")

if [ "${#RULES[@]}" -eq 0 ]; then
  echo "ERROR: no ## rule headings found in $RULES_MD" >&2
  exit 2
fi

if [ ! -f "$FILE" ]; then
  echo "NO_FILE"
  exit 0
fi

for rule in "${RULES[@]}"; do
  key="${rule% (*)}"
  if awk -v h="## $key" '
    BEGIN { h = tolower(h) }
    index(tolower($0), h) == 1 { found = 1; exit }
    END { exit !found }
  ' "$FILE"; then
    echo "present: $rule"
  else
    echo "missing: $rule"
  fi
done
