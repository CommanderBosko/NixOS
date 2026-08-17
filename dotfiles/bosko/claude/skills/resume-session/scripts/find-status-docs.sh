#!/usr/bin/env bash
# find-status-docs.sh — Locate a project's status/progress doc(s) by filename.
#
# Usage: find-status-docs.sh <dir> <pattern1> [pattern2 ...]
# Issues one `-iname <pattern>` find call per pattern (never a compound `-o`
# predicate — some environments' `find` reject those outright) and prints
# every match, one per line. Read-only.
set -uo pipefail

DIR="${1:?usage: find-status-docs.sh <dir> <pattern1> [pattern2 ...]}"
shift

if [ "$#" -eq 0 ]; then
  echo "usage: find-status-docs.sh <dir> <pattern1> [pattern2 ...]" >&2
  exit 1
fi

for pattern in "$@"; do
  find "$DIR" -maxdepth 2 -iname "$pattern"
done
