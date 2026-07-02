---
name: git-push
description: Push the current branch to the remote GitHub repository. Use when the user says "push", "git push", "push to github", "push my changes", or "send to github".
---

# Git Push Skill

Push the current branch to origin on GitHub.

## Steps

1. Run these in parallel:
   - `git status` — confirm working tree is clean (warn if there are uncommitted changes)
   - `git log --oneline origin/$(git branch --show-current)..HEAD` — show what commits will be pushed
   - `git branch --show-current` — get the current branch name

2. If there are uncommitted changes, warn the user and ask if they want to commit first (suggest `/git-commit`).

3. Show which commits are ahead of the upstream (from step 1's log output) before pushing.

4. Confirm:
   - **Skip confirmation** if the user's original request was an unambiguous push command with no
     conditions attached (e.g. "push it", "just push", "push now") — proceed straight to step 5.
   - **Ask for confirmation** in all other cases (e.g. "push", "push my changes"). A one-word
     reply or `y` is sufficient to proceed.

5. Determine if the branch has an upstream:
   - `git rev-parse --abbrev-ref --symbolic-full-name @{u}` 2>/dev/null
   - If no upstream exists, push with `-u` flag to set it: `git push -u origin <branch>`
   - If upstream exists, push normally: `git push`

6. Run the push.

7. Report: how many commits were pushed, the branch name, and the remote URL.

## Rules

- NEVER force push (`--force` or `-f`) to `main` or `master` — warn the user if they request it
- Only force push if the user explicitly requests it AND the branch is not main/master
- Do not push if there are no commits ahead of origin (nothing to push)
- If the push is rejected (non-fast-forward), explain why and suggest `git pull --rebase` rather than force pushing
