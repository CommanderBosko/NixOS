#!/usr/bin/env bash
# Mechanical git-commit helpers: state gathering, then staging + commit.
# Usage:
#   git-commit.sh status              — print status, diff, and recent log style
#   git-commit.sh commit <file>...     — stage the given files by name, then read
#                                        the commit message from stdin and commit
set -euo pipefail

MODE="${1:-status}"

case "$MODE" in
  status)
    echo "--- git status ---"
    git status
    echo "--- git diff ---"
    git diff
    echo "--- recent commit style ---"
    git log --oneline -5
    ;;
  commit)
    shift
    if [ "$#" -eq 0 ]; then
      echo "usage: git-commit.sh commit <file>..." >&2
      exit 1
    fi
    git add -- "$@"
    git commit -F -
    echo "--- git status ---"
    git status
    ;;
  *)
    echo "usage: git-commit.sh {status|commit <file>...}" >&2
    exit 1
    ;;
esac
