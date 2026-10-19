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
   working-tree status, and the commits ahead of upstream. With no upstream yet, it lists the
   commits not on origin's default branch (`origin/HEAD`, falling back to `origin/main`, then
   `origin/master`), not the whole history.

2. If there are uncommitted changes, warn the user and ask via the **AskUserQuestion** tool with
   options **Commit first** / **Push anyway** / **Cancel**. Uncommitted changes are never pushed, so
   **Push anyway** pushes only the existing commits.
   - **Commit first**: run the `git-commit` skill, then re-run step 1 and continue.
   - **Push anyway**: continue to step 3.
   - **Cancel**: stop without pushing.

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
   if so), and prints the branch name and remote URL. If `origin/<branch>..HEAD` is empty it
   pushes nothing, prints `nothing to push: ...`, and exits 0 — report that instead of step 6.

6. Report: how many commits were pushed, the branch name, and the remote URL (from step 5's output).
   If git printed a `https://github.com/<owner>/<repo>/pull/new/<branch>` link, mention it as an
   "open a PR" link only (see Gotchas).

## Rules

- NEVER force push (`--force` or `-f`) to `main` or `master` — warn the user if they request it
- Only force push if the user explicitly requests it AND the branch is not main/master
- Do not push if there are no commits ahead of origin (nothing to push) — `push.sh execute` enforces this too
- If the push is rejected (non-fast-forward), explain why and suggest `git pull --rebase` rather than force pushing
- Step 4's confirm-skip check is for a standalone push request reaching this skill directly. A skill whose own description/invocation already commits to pushing (e.g. `session-closer`'s end-of-session close, which is a "wrap up and push" ask by name) treats that invocation itself as the consent and doesn't re-ask here — that's intentional, not a gap in this skill's confirm logic.

## Gotchas

- **The `pull/new/<branch>` link is not a pending PR.** After a push, git prints
  `https://github.com/<owner>/<repo>/pull/new/<branch>` as a convenience. It only opens GitHub's
  "new pull request" form for that branch. Nothing is waiting for review, and no PR exists until
  someone opens and submits that form. Don't report it as an open PR or as a reminder to review.
- **Script paths:** use the absolute path from this skill's Base directory line, never a bare `scripts/...` — see `~/.claude/skills/lib/script-paths.md`.
