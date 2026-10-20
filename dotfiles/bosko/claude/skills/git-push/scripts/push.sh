#!/usr/bin/env bash
# Mechanical git-push helpers: state gathering, then the actual push.
# Usage:
#   push.sh status    — print working-tree status, branch, and commits ahead of upstream
#   push.sh execute   — push (with -u if no upstream yet) and report the result;
#                       exits 0 without pushing if origin/<branch>..HEAD is empty.
#                       If the branch is origin's default branch and the push is rejected by
#                       a protection rule (GH013 / PR required), falls back to: new pr/<slug>-<sha>
#                       branch at HEAD, push it, `gh pr create`, reset local default branch to
#                       origin/<default> (clean tree only), stay on the PR branch. Never forces.
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
      PUSH=(git push)
    else
      PUSH=(git push -u origin "$BRANCH")
    fi
    # Capture output so protection errors can be pattern-matched, but still show it.
    if ! OUT="$("${PUSH[@]}" 2>&1)"; then
      echo "$OUT" >&2
      DEFAULT="$(default_base 2>/dev/null || true)"
      DEFAULT="${DEFAULT#origin/}"
      if [ -n "$DEFAULT" ] && [ "$BRANCH" = "$DEFAULT" ] &&
        grep -qiE 'GH013|Repository rule violations|protected branch|must be made through a pull request' <<<"$OUT"; then
        N="$(git rev-list --count "origin/$DEFAULT..HEAD")"
        SUBJECT="$(git log -1 --format=%s)"
        SLUG="$(tr '[:upper:]' '[:lower:]' <<<"$SUBJECT" | tr -c 'a-z0-9\n' '-' | tr -s '-' | cut -c1-40 | sed 's/^-//; s/-$//')"
        PR_BRANCH="pr/${SLUG:-changes}-$(git rev-parse --short=7 HEAD)"
        echo "$DEFAULT is protected: pushing $PR_BRANCH and opening a PR instead" >&2
        git switch -c "$PR_BRANCH"
        git push -u origin "$PR_BRANCH"
        PR_URL="$(gh pr create --fill --base "$DEFAULT" --head "$PR_BRANCH")"
        echo "$PR_URL"
        if [ -z "$(git status --porcelain)" ]; then
          git branch -f "$DEFAULT" "origin/$DEFAULT"
          RESET="local $DEFAULT reset to origin/$DEFAULT"
        else
          RESET="WARNING: working tree dirty, local $DEFAULT NOT reset (run: git branch -f $DEFAULT origin/$DEFAULT)"
        fi
        echo "$DEFAULT is protected: pushed $N commit(s) as PR $PR_URL; $RESET; merge via land-prs"
        exit 0
      fi
      exit 1
    fi
    echo "$OUT"
    echo "--- pushed ---"
    echo "branch: $BRANCH"
    git remote get-url origin
    ;;
  *)
    echo "usage: push.sh {status|execute}" >&2
    exit 1
    ;;
esac
