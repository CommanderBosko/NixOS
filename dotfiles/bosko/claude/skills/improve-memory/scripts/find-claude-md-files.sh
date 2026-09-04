#!/usr/bin/env bash
# Finds a project's real CLAUDE.md files: its root CLAUDE.md (if any) plus any
# subdirectory CLAUDE.md files already in the tree. improve-memory needs these
# to know what already exists before proposing restructuring -- Claude Code's
# real on-demand memory-loading mechanism is a literal CLAUDE.md placed in a
# subdirectory, auto-loaded when a file in that subtree is read/edited, no
# special naming or explicit reference required.
#
# Usage: find-claude-md-files.sh <real-project-path>
#
# Prints one absolute path per line. Excludes common non-project noise dirs
# via a grep -v pipeline -- this repo's `find` (rtk find) rejects compound
# predicates like -not/-prune, so exclusion has to be a pipeline step, not a
# find flag.
set -uo pipefail

PROJECT_PATH="${1:?usage: find-claude-md-files.sh <real-project-path>}"

if [ ! -d "$PROJECT_PATH" ]; then
  echo "not a directory: $PROJECT_PATH" >&2
  exit 1
fi

find "$PROJECT_PATH" -iname "CLAUDE.md" 2>/dev/null \
  | grep -v -e '/node_modules/' -e '/\.git/' -e '/vendor/'
exit 0
