---
name: git-push
description: Push the current branch to the remote GitHub repository. Use when the user says "push", "git push", "push to github", "push my changes", or "send to github".
model: haiku
---

# Git Push Skill

Push the current branch to origin on GitHub.

## Steps

The status gathering and the push itself are both mechanical (fixed git commands, no
judgment involved), so they're handled by a script — only the confirm-skip decision in step
4 needs judgment and stays here.

1. Run `/home/bosko/.claude/skills/git-push/scripts/push.sh status` — prints the current branch,
   working-tree status, and the commits ahead of upstream (or all commits, if there's no upstream yet).

2. If there are uncommitted changes, warn the user and ask if they want to commit first (suggest `/git-commit`).

3. Show which commits are ahead of the upstream (from step 1's output) before pushing.

4. Confirm:
   - **Skip confirmation** if the user's original request was an unambiguous push command with no
     conditions attached (e.g. "push it", "just push", "push now") — proceed straight to step 5.
   - **Ask for confirmation** in all other cases (e.g. "push", "push my changes"), via the
     AskUserQuestion tool with options **Proceed** / **Cancel**.

5. Run `/home/bosko/.claude/skills/git-push/scripts/push.sh execute` — determines whether the
   branch has an upstream, pushes accordingly (`git push -u origin <branch>` if not, `git push`
   if so), and prints the branch name and remote URL.

6. Report: how many commits were pushed, the branch name, and the remote URL (from step 5's output).

## Rules

- NEVER force push (`--force` or `-f`) to `main` or `master` — warn the user if they request it
- Only force push if the user explicitly requests it AND the branch is not main/master
- Do not push if there are no commits ahead of origin (nothing to push)
- If the push is rejected (non-fast-forward), explain why and suggest `git pull --rebase` rather than force pushing

## Gotchas

- **"relative to this skill's directory" is not the shell's cwd.** This is a global,
  home-symlinked skill, and the Bash tool's working directory during a run is the project
  root, not this skill's directory. Resolve the full absolute path from this skill's "Base
  directory" line (e.g. `/home/bosko/.claude/skills/git-push/scripts/push.sh`) rather than
  guessing a project-relative `.claude/skills/git-push/...` path — the guess reliably 404s
  with exit 127 (observed 2026-07-25).
