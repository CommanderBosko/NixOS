#!/usr/bin/env bash
# Mechanical scan helpers for the session-closer skill.
# Usage:
#   scan-session.sh git-changes [repo-root]     — baseline commit + diff/status/stat
#   scan-session.sh transcript [project-dir]    — JSONL since session-closer's last run
#                                                  (all sessions since then), user+assistant turns
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

    # Scope to every transcript touched since session-closer's own last run,
    # so a close spanning several unclosed sessions reads all of them, not
    # just the single most-recently-modified file.
    CUTOFF="$("$LIB_DIR/find-last-skill-invocation.sh" session-closer "$PROJECT_DIR" 2>/dev/null)"

    if [ -n "$CUTOFF" ]; then
      echo "--- transcripts since last session-closer run ($CUTOFF) ---"
      FILES="$("$LIB_DIR/list-transcripts-since.sh" "$CUTOFF" "$PROJECT_DIR")"
    else
      echo "--- no prior session-closer run found; using latest transcript only ---"
      FILES="$(cd "$DIR" && ls -t -- *.jsonl 2>/dev/null | head -1)"
    fi

    if [ -z "$FILES" ]; then
      echo "no transcript found under $DIR" >&2
      exit 1
    fi

    while IFS= read -r FN; do
      [ -z "$FN" ] && continue
      FILE="$DIR/$FN"
      echo "--- transcript: $FILE ---"

      echo "--- user turns ---"
      jq -r 'select(.type=="user") | .message.content
             | if type=="string" then . else (.[]? | select(.type=="text") .text) end' "$FILE"

      echo "--- assistant narrative ---"
      jq -r 'select(.type=="assistant") | .message.content[]? | select(.type=="text") .text' "$FILE"
    done <<< "$FILES"
    ;;

  *)
    echo "usage: scan-session.sh {git-changes [repo-root]|transcript [project-dir]}" >&2
    exit 1
    ;;
esac
