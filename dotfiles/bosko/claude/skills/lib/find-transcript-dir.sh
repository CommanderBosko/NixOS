#!/usr/bin/env bash
# Resolve a project directory's Claude Code session-transcript directory under
# ~/.claude/projects/. Shared by skill-upgrade, session-closer, and
# skill-suggestion so the cwd-to-slug derivation lives in exactly one place
# instead of being independently re-derived per skill.
#
# Usage: find-transcript-dir.sh [project-dir]
#   project-dir  defaults to $PWD
#
# Prints the resolved directory path on stdout. Exits 1 (message on stderr)
# if it doesn't exist -- callers wanting a soft-fail should catch that rather
# than treat a missing directory as unconditionally fatal.
set -uo pipefail

PROJECT_DIR="${1:-$PWD}"
SLUG="$(echo "$PROJECT_DIR" | sed 's#/#-#g')"
DIR="$HOME/.claude/projects/${SLUG}"

if [ ! -d "$DIR" ]; then
  echo "no transcript directory found at $DIR" >&2
  exit 1
fi

echo "$DIR"
