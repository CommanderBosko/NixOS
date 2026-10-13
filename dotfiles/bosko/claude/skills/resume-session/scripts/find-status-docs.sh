#!/usr/bin/env bash
# find-status-docs.sh — Locate a project's status/progress doc(s) by filename.
#
# Usage: find-status-docs.sh <dir> [pattern1 pattern2 ...]
# With no patterns, searches the default status-doc list below. Pass patterns
# to search only those instead (a documented convention, or filenames the user
# named). Issues one `-iname <pattern>` find call per pattern (never a compound
# `-o` predicate — some environments' `find` reject those outright) and prints
# every match, one per line. Read-only.
set -uo pipefail

DEFAULT_PATTERNS=(
  project-state.md
  session-summary.md
  STATUS.md
  PROGRESS.md
  NOTES.md
  CHANGELOG.md
)

DIR="${1:?usage: find-status-docs.sh <dir> [pattern1 pattern2 ...]}"
shift

if [ "$#" -eq 0 ]; then
  set -- "${DEFAULT_PATTERNS[@]}"
fi

for pattern in "$@"; do
  find "$DIR" -maxdepth 2 -iname "$pattern"
done
