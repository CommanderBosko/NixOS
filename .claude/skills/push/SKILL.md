---
name: push
description: Use this skill when the user wants to "push", "push to origin", "push my changes", "push it", "send to GitHub", or "push to remote". It shows which commits will be pushed, confirms with the user (unless the intent was already an explicit command), then pushes and reports the result.
version: 0.1.0
---

# Git Push Workflow

Push committed changes in `/home/bosko/NixOS` to `origin main`. Never force-push to main. Always show what will be pushed before pushing.

## Step 1 — Check ahead/behind status

```bash
git -C /home/bosko/NixOS status
git -C /home/bosko/NixOS log --oneline origin/main..HEAD
```

If there are **no commits ahead of origin**, tell the user there is nothing to push and stop.

If the branch is **behind** origin (i.e. `git status` shows "behind"), warn the user and do not push until they decide how to handle it (pull and rebase, or confirm they want to push anyway).

## Step 2 — Show what will be pushed

List the commits that are ahead of `origin/main` (from Step 1's log output). Present them clearly:

```
Commits to be pushed to origin/main:
  abc1234  feat(skills): add commit skill
  def5678  chore(memory): record skill workflow feedback
```

Also note the total count: e.g. "2 commits ahead of origin/main."

## Step 3 — Confirm (when needed)

**Skip confirmation** if the user's original request was an unambiguous push command with no conditions attached (e.g. "push it", "just push", "push now"). In that case, proceed directly to Step 4.

**Ask for confirmation** in all other cases — e.g. "push", "push my changes", "push to origin". A one-word reply or `y` from the user is sufficient to proceed.

## Step 4 — Push

```bash
git -C /home/bosko/NixOS push origin main
```

Constraints:
- Never use `--force` or `--force-with-lease` to main without an explicit user instruction. If the push is rejected and force would be required, explain why and let the user decide.
- Never pass `--no-verify`.

## Step 5 — Report result

On success, show the remote ref range reported by git (e.g. `abc123..def456  main -> main`) so the user can confirm what landed. If pushing a first-time branch, note the tracking ref that was set.

On failure, show the full error output and suggest a resolution:
- Rejected (non-fast-forward): suggest `git pull --rebase origin main` then retry.
- Authentication error: check SSH key or HTTPS credentials.
- Other: show raw error and wait for user guidance.

---

## Key constraints

- This repo's working directory is always `/home/bosko/NixOS` — always pass `-C /home/bosko/NixOS` to every git command.
- The remote is `origin`, the branch is `main`.
- Do not commit — committing is a separate skill (`commit`).
- Do not force-push to main.
