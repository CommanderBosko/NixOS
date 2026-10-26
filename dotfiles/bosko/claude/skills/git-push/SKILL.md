---
name: git-push
description: Push the current branch to the remote GitHub repository, and on a feature branch with no open PR also open the PR against the default branch (never merges). Use when the user says "push", "git push", "push to github", "push my changes", "send to github", "push and open a PR", or "open a PR".
model: haiku
---

# Git Push Skill

Push the current branch to origin on GitHub. On a non-default branch with no open PR, also open one
against the default branch — the branch-off / commit / push / `gh pr create` flow in one step. This
skill only ever opens PRs; it never merges one.

## Steps

The status gathering, the push, and the PR creation are all mechanical (fixed git/gh commands, no
judgment involved), so they're handled by a script — only the confirm-skip decision in step 4 and
the PR title confirmation need judgment and stay here.

1. Run `/home/bosko/.claude/skills/git-push/scripts/push.sh status` — prints the current branch,
   working-tree status, and the commits ahead of upstream. With no upstream yet, it lists the
   commits not on origin's default branch (`origin/HEAD`, falling back to `origin/main`, then
   `origin/master`), not the whole history. On a **non-default branch** it also prints a
   `--- pull request ---` section: either `open PR: <url>` (execute will only push), or `no open PR`
   followed by the title and body that execute will use.

2. If there are uncommitted changes, warn the user and ask via the **AskUserQuestion** tool with
   options **Commit first** / **Push anyway** / **Cancel**. Uncommitted changes are never pushed, so
   **Push anyway** pushes only the existing commits.
   - **Commit first**: run the `git-commit` skill, then re-run step 1 and continue.
   - **Push anyway**: continue to step 3.
   - **Cancel**: stop without pushing.

3. Show which commits are ahead of the upstream (from step 1's output) before pushing. If step 1
   said `no open PR`, also show the drafted PR title and say the push will open a PR.

4. Confirm:
   - **Skip confirmation** if the user's original request was an unambiguous, unconditional
     go-ahead to push right now (e.g. "push it", "just push", "push now", or any clearly
     equivalent phrasing) — proceed straight to step 5 with the drafted title.
   - **Ask for confirmation** whenever that intent isn't clearly there (e.g. a bare "push" or
     "push my changes" with nothing else signaling "right now, unconditionally"), via the
     AskUserQuestion tool. Judge the actual phrasing and context — the examples above illustrate
     the two ends, not an exhaustive list to pattern-match against.
     - When the push will **also open a PR**, put the drafted title in the question and offer
       **Proceed** (push and open the PR) / **Push only** (no PR, step 5 gets `--no-pr`) /
       **Cancel**. If the user types a different title via Other, pass it as `--title "<text>"`.
     - Otherwise (default branch, or a PR is already open) offer **Proceed** / **Cancel**.

5. Run `/home/bosko/.claude/skills/git-push/scripts/push.sh execute [--title "<text>"] [--body-file <path>] [--base <branch>] [--no-pr]`
   — determines whether the branch has an upstream, pushes accordingly (`git push -u origin <branch>`
   if not, `git push` if so), and prints the branch name and remote URL. If `origin/<branch>..HEAD`
   is empty it pushes nothing and prints `nothing to push: ...` — report that instead of step 6
   (on a feature branch it may still open a missing PR, see below).

   **Feature branch (anything but the default branch):** after the push the script checks that
   origin really has the commit, then looks for an open PR with this branch as head. If one exists it
   prints its URL and does nothing else. If none exists it runs `gh pr create --base <default
   branch>` with a drafted Summary (commit subjects, plus the commit body for a single commit) and
   Verification (diff stat) body ending in the Claude Code attribution line; title = the oldest
   commit's subject unless `--title` is given. Report the PR URL.
   - A nothing-to-push re-run still opens the PR if the branch is on origin and has none — that is how
     a retry after a failed PR step works.
   - `--base <branch>`: for a stacked branch whose PR should target its parent, not the default branch
     (use it when the user says the branch builds on another one).
   - `--body-file <path>`: replaces the drafted body. If this session ran concrete checks (a dry-run,
     tests, a `flake-check`), write them under a `## Verification` heading in a temp file and pass it —
     list only checks that actually ran, never invent any — and keep the attribution line last.
   - Exit code `2` means the push succeeded but the PR step failed (`gh` missing, not authenticated,
     or `gh pr create` rejected it). Show the script's error verbatim, tell the user the branch is
     already pushed, and stop — don't retry in a loop or fall back to opening the PR by hand.

   **Protected default branch:** if the current branch is the remote default branch and the push
   is rejected by a ruleset (GH013 / "must be made through a pull request"), the script falls back
   on its own: it pushes the commits as a new `pr/<slug>-<sha>` branch, opens a PR with
   `gh pr create`, resets local `main` to `origin/main` (clean tree only) and stays on the PR
   branch. The PR is not merged automatically; merging is the `land-prs` skill's job. Report the PR
   URL and tell the user to merge via land-prs. On the default branch nothing else changes — no PR
   lookup happens.

6. Report: how many commits were pushed, the branch name, the remote URL (from step 5's output), and
   the PR URL when one was opened or already existed. A `pull/new/<branch>` link that git printed is
   redundant once there is a PR URL — leave it out (see Gotchas).

## Rules

- NEVER force push (`--force` or `-f`) to `main` or `master` — warn the user if they request it
- Only force push if the user explicitly requests it AND the branch is not main/master
- Never merge a PR (no `gh pr merge`, no `--auto`) — this skill opens PRs only; merging is `land-prs`'s job
- Do not push if there are no commits ahead of origin (nothing to push) — `push.sh execute` enforces this too
- If the push is rejected (non-fast-forward), explain why and suggest `git pull --rebase` rather than force pushing
- Step 4's confirm-skip check is for a standalone push request reaching this skill directly. A skill whose own description/invocation already commits to pushing (e.g. `session-closer`'s end-of-session close, which is a "wrap up and push" ask by name) treats that invocation itself as the consent and doesn't re-ask here — that's intentional, not a gap in this skill's confirm logic.

## Gotchas

- **A branch cut from `origin/main` tracks `main`.** `git checkout -b X origin/main` (no `--no-track`)
  leaves `X` with upstream `origin/main`, so a bare `git push` refuses ("upstream branch ... does not
  match the name of your current branch") and `status` used to die on `origin/X..HEAD`. `push.sh` now
  detects any origin upstream whose name differs from the branch, prints a `note:`, and pushes with
  `git push -u origin <branch>` (which also fixes the upstream). Prefer creating branches with
  `git checkout -b X --no-track origin/main`, and don't pipe `execute` through `tail` — it hides errors.
- **The `pull/new/<branch>` link is not a pending PR.** After a push, git prints
  `https://github.com/<owner>/<repo>/pull/new/<branch>` as a convenience. It only opens GitHub's
  "new pull request" form for that branch. Nothing is waiting for review, and no PR exists until
  someone opens and submits that form. Don't report it as an open PR or as a reminder to review. On a
  feature branch `push.sh` now opens the PR itself, so report that PR URL instead.
- **Existing-PR check matches the head branch only, any base.** A stacked child PR that targets its
  parent is found and not duplicated. A *new* PR still targets the default branch unless `--base` says otherwise.
- **Script paths:** use the absolute path from this skill's Base directory line, never a bare `scripts/...` — see `~/.claude/skills/lib/script-paths.md`.
