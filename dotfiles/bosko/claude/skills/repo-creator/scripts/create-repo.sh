#!/usr/bin/env bash
# Mechanical repo-creator helpers: init, GitHub repo creation, and the final
# stage/commit/push. Commit-message drafting stays in the SKILL (judgment).
# Usage:
#   create-repo.sh init                    — git init + checkout main if needed;
#                                             prints existing-commit-count so the
#                                             caller can decide whether to pause
#                                             and confirm before continuing
#   create-repo.sh create <repo-name>      — gh repo create (public, SSH remote)
#   create-repo.sh push <commit-msg-file>  — git add ., commit using the message
#                                             file's contents, push -u origin main
set -euo pipefail

MODE="${1:-}"

case "$MODE" in
  init)
    if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      COMMIT_COUNT="$(git rev-list --count HEAD 2>/dev/null || echo 0)"
      echo "existing-repo: true"
      echo "existing-commits: $COMMIT_COUNT"
      CURRENT_BRANCH="$(git branch --show-current)"
      if [ "$CURRENT_BRANCH" != "main" ]; then
        git checkout -b main
      fi
    else
      git init
      git checkout -b main
      echo "existing-repo: false"
      echo "existing-commits: 0"
    fi
    ;;
  create)
    REPO_NAME="${2:?usage: create-repo.sh create <repo-name>}"
    gh repo create "CommanderBosko/$REPO_NAME" --public --source=. --remote=origin --push=false
    REMOTE_URL="$(git remote get-url origin)"
    case "$REMOTE_URL" in
      https://*)
        git remote set-url origin "git@github.com:CommanderBosko/$REPO_NAME.git"
        ;;
    esac
    git remote -v
    ;;
  push)
    MSG_FILE="${2:?usage: create-repo.sh push <commit-msg-file>}"
    git add .
    git commit -F "$MSG_FILE"
    git push -u origin main
    echo "--- pushed ---"
    git remote get-url origin
    ;;
  *)
    echo "usage: create-repo.sh {init|create <repo-name>|push <commit-msg-file>}" >&2
    exit 1
    ;;
esac
