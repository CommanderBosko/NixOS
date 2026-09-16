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
   - **Skip confirmation** if the user's original request was an unambiguous, unconditional
     go-ahead to push right now (e.g. "push it", "just push", "push now", or any clearly
     equivalent phrasing) — proceed straight to step 5.
   - **Ask for confirmation** whenever that intent isn't clearly there (e.g. a bare "push" or
     "push my changes" with nothing else signaling "right now, unconditionally"), via the
     AskUserQuestion tool with options **Proceed** / **Cancel**. Judge the actual phrasing and
     context — the examples above illustrate the two ends, not an exhaustive list to
     pattern-match against.

5. Run `/home/bosko/.claude/skills/git-push/scripts/push.sh execute` — determines whether the
   branch has an upstream, pushes accordingly (`git push -u origin <branch>` if not, `git push`
   if so), and prints the branch name and remote URL.

6. Report: how many commits were pushed, the branch name, and the remote URL (from step 5's output).

## Rules

- NEVER force push (`--force` or `-f`) to `main` or `master` — warn the user if they request it
- Only force push if the user explicitly requests it AND the branch is not main/master
- Do not push if there are no commits ahead of origin (nothing to push)
- If the push is rejected (non-fast-forward), explain why and suggest `git pull --rebase` rather than force pushing
- Step 4's confirm-skip check is for a standalone push request reaching this skill directly. A skill whose own description/invocation already commits to pushing (e.g. `session-closer`'s end-of-session close, which is a "wrap up and push" ask by name) treats that invocation itself as the consent and doesn't re-ask here — that's intentional, not a gap in this skill's confirm logic.

## Gotchas

- **"relative to this skill's directory" is not the shell's cwd.** This is a global,
  home-symlinked skill, and the Bash tool's working directory during a run is the project
  root, not this skill's directory. Resolve the full absolute path from this skill's "Base
  directory" line (e.g. `/home/bosko/.claude/skills/git-push/scripts/push.sh`) rather than
  guessing a project-relative `.claude/skills/git-push/...` path — the guess reliably 404s
  with exit 127 (observed 2026-07-25).
