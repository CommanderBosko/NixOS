#!/usr/bin/env bash
# Mechanical git-push helpers: state gathering, then the actual push.
# Usage:
#   push.sh status    — print working-tree status, branch, and commits ahead of upstream
#   push.sh execute   — push (with -u if no upstream yet) and report the result;
#                       exits 0 without pushing if origin/<branch>..HEAD is empty
set -euo pipefail

MODE="${1:-status}"

# Base to compare against when the branch has no upstream: origin's default branch
# (origin/HEAD), falling back to origin/main, then origin/master. Prints nothing and
# returns 1 if none exists.
default_base() {
  local ref
  ref="$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null || true)"
  if [ -n "$ref" ] && git rev-parse --verify --quiet "$ref" >/dev/null; then
    echo "$ref"
    return 0
  fi
  for ref in origin/main origin/master; do
    if git rev-parse --verify --quiet "$ref" >/dev/null; then
      echo "$ref"
      return 0
    fi
  done
  return 1
}

case "$MODE" in
  status)
    BRANCH="$(git branch --show-current)"
    echo "branch: $BRANCH"
    echo "--- git status ---"
    git status --short
    echo "--- commits ahead of upstream ---"
    if git rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1; then
      git log --oneline "origin/$BRANCH..HEAD"
    elif BASE="$(default_base)"; then
      echo "(no upstream set yet — commits not on $BASE)"
      git log --oneline "$BASE..HEAD"
    else
      echo "(no upstream set yet and no origin default branch found — all commits on $BRANCH shown)"
      git log --oneline
    fi
    ;;
  execute)
    BRANCH="$(git branch --show-current)"
    if git rev-parse --verify --quiet "refs/remotes/origin/$BRANCH" >/dev/null; then
      AHEAD="$(git rev-list --count "origin/$BRANCH..HEAD")"
      if [ "$AHEAD" -eq 0 ]; then
        echo "nothing to push: $BRANCH has no commits ahead of origin/$BRANCH"
        exit 0
      fi
    elif BASE="$(default_base)" && [ "$(git rev-list --count "$BASE..HEAD")" -eq 0 ]; then
      echo "nothing to push: $BRANCH has no commits ahead of $BASE"
      exit 0
    fi
    if git rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1; then
      git push
    else
      git push -u origin "$BRANCH"
    fi
    echo "--- pushed ---"
    echo "branch: $BRANCH"
    git remote get-url origin
    ;;
  *)
    echo "usage: push.sh {status|execute}" >&2
    exit 1
    ;;
esac
