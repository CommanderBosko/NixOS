#!/usr/bin/env bash
# Mechanical heading-presence check for the five standing rules against a
# CLAUDE.md file. Prints "present" or "missing" per rule; does not edit
# anything. Judgment calls (ambiguous/variant headings) stay in the SKILL.
# Usage: check-rules.sh <path-to-CLAUDE.md>
set -euo pipefail

FILE="${1:?usage: check-rules.sh <path-to-CLAUDE.md>}"

if [ ! -f "$FILE" ]; then
  echo "NO_FILE"
  exit 0
fi

declare -A RULES=(
  ["Scope First"]="## Scope First"
  ["Verification Plan"]="## Verification Plan"
  ["Parallelize with Sub-Agents"]="## Parallelize with Sub-Agents"
  ["Use Existing Skills First"]="## Use Existing Skills First"
  ["Ask via AskUserQuestion"]="## Ask via AskUserQuestion"
)

for rule in "Scope First" "Verification Plan" "Parallelize with Sub-Agents" "Use Existing Skills First" "Ask via AskUserQuestion"; do
  heading="${RULES[$rule]}"
  if grep -qi "^${heading}" "$FILE"; then
    echo "present: $rule"
  else
    echo "missing: $rule"
  fi
done
