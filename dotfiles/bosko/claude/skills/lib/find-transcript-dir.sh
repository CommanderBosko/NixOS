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
slug_dir() { echo "$HOME/.claude/projects/$(echo "$1" | sed 's#/#-#g')"; }
DIR="$(slug_dir "$PROJECT_DIR")"

# A linked git worktree (e.g. a manager agent's .claude/worktrees/agent-*) has
# no transcript dir of its own -- its sessions are logged under the main checkout.
if [ ! -d "$DIR" ]; then
  COMMON="$(git -C "$PROJECT_DIR" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)"
  [ -n "$COMMON" ] && DIR="$(slug_dir "$(dirname "$COMMON")")"
fi

if [ ! -d "$DIR" ]; then
  echo "no transcript directory found at $DIR" >&2
  exit 1
fi

echo "$DIR"
