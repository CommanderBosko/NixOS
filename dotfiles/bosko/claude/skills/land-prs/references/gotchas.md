# Land PRs — Gotchas

Load this when a step 5–7 Bash call is denied by the auto-mode classifier, or before bundling cleanup commands into one call.

- **A `git push origin --delete` inside an `&&` chain gets the whole chain blocked.** Seen on 2026-10-12 in blueprint-smith, after PRs #2–#4 had landed. One chain held the tree check, the checkout, the fast-forward, the remote delete, `git branch -d` and the prune. The Claude Code auto-mode classifier denied all of it as `[Git Destructive]`, so even the safe steps didn't run. It had to be rerun without the deletes. A similar bundle for PR #1 had gone through in an earlier session, so you can't predict when the block will hit. The reliable fix is to give the remote delete its own confirmed Bash call (step 7). The same applies to `scripts/merge-step.sh delete-remote`, which runs that `git push origin --delete`.
