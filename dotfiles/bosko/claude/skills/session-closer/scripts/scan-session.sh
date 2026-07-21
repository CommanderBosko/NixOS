#!/usr/bin/env bash
# Mechanical scan helpers for the session-closer skill.
# Usage:
#   scan-session.sh git-changes [repo-root]     — baseline commit + diff/status/stat
#   scan-session.sh transcript [project-dir]    — this session's JSONL, user+assistant turns
set -uo pipefail

MODE="${1:-}"

case "$MODE" in
  git-changes)
    ROOT="${2:-.}"
    cd "$ROOT" || { echo "no such repo root: $ROOT" >&2; exit 1; }

    # No --all here: it pulls in stash entries (refs/stash shows up as "WIP on
    # main:"/"index on main:" commits) and other branches' unrelated history,
    # flooding the range with noise that has nothing to do with this session.
    BASELINE="$(git log --oneline | grep "chore(session):" | head -1 | cut -d' ' -f1)"
    if [ -z "$BASELINE" ]; then
      echo "--- no prior chore(session) commit found; falling back to --since=midnight ---"
      echo "--- commits since midnight ---"
      git log --oneline --since='midnight'
    else
      echo "--- baseline: $BASELINE ---"
      echo "--- commits since baseline ---"
      git log --oneline "$BASELINE"..HEAD
    fi

    echo "--- diff vs origin/main (unpushed) ---"
    git diff origin/main...HEAD

    echo "--- git status ---"
    git status

    if [ -n "$BASELINE" ]; then
      echo "--- stat since baseline ---"
      git log --stat "$BASELINE"..HEAD
    fi
    ;;

  transcript)
    PROJECT_DIR="${2:-$(pwd)}"
    LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../lib" && pwd)"
    DIR="$("$LIB_DIR/find-transcript-dir.sh" "$PROJECT_DIR")" || exit 1
    LATEST="$(ls -t "$DIR"/*.jsonl 2>/dev/null | head -1)"

    if [ -z "$LATEST" ]; then
      echo "no transcript found under $DIR" >&2
      exit 1
    fi

    echo "--- transcript: $LATEST ---"

    echo "--- user turns ---"
    jq -r 'select(.type=="user") | .message.content
           | if type=="string" then . else (.[]? | select(.type=="text") .text) end' "$LATEST"

    echo "--- assistant narrative ---"
    jq -r 'select(.type=="assistant") | .message.content[]? | select(.type=="text") .text' "$LATEST"
    ;;

  *)
    echo "usage: scan-session.sh {git-changes [repo-root]|transcript [project-dir]}" >&2
    exit 1
    ;;
esac
