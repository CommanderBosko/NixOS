# Git Push — Gotchas

Load this when a push or PR step behaves unexpectedly: a new branch won't push, the `pull/new/<branch>` link shows up after a push, or `--pr` re-opens or skips a PR you did not expect.

- **A branch cut from `origin/main` tracks `main`.** `git checkout -b X origin/main` (no `--no-track`)
  leaves `X` with upstream `origin/main`, so a bare `git push` refuses ("upstream branch ... does not
  match the name of your current branch") and `status` used to die on `origin/X..HEAD`. `push.sh` now
  detects any origin upstream whose name differs from the branch, prints a `note:`, and pushes with
  `git push -u origin <branch>` (which also fixes the upstream). Prefer creating branches with
  `git checkout -b X --no-track origin/main`, and don't pipe `execute` through `tail` — it hides errors.
  (The default branch is never retargeted — it keeps its old behavior exactly.)
- **`--no-track` goes before `-c` with `git switch`.** `git switch -c --no-track X origin/main` fails
  with `fatal: only one reference expected`, because `-c` consumes the next word as the new branch
  name (seen in two separate sessions, 2026-10 and 2026-11). Write
  `git switch --no-track -c X origin/main` (or the `git checkout -b X --no-track origin/main` form
  above). The result has no upstream configured at all, which is intended: the first push sets it
  with `git push -u origin X`, as `push.sh` does.
- **The `pull/new/<branch>` link is not a pending PR.** After a push, git prints
  `https://github.com/<owner>/<repo>/pull/new/<branch>` as a convenience. It only opens GitHub's
  "new pull request" form for that branch. Nothing is waiting for review, and no PR exists until
  someone opens and submits that form. Don't report it as an open PR or as a reminder to review. When
  `execute --pr` opened the PR, report that PR URL instead.
- **Existing-PR check matches the head branch, any base, any state.** A stacked child PR that targets
  its parent is found and not duplicated, and a branch whose PR was squash-merged isn't re-opened by a
  repeat `--pr` run with nothing new to push. A *new* PR still targets the default branch unless
  `--base` says otherwise.
