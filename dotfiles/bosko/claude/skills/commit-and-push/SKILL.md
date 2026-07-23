---
name: commit-and-push
description: Commit the current changes and push them to the remote in one go. Use when the user says "commit and push", "commit & push", "ship this change", or "save and push".
model: haiku
---

# Commit and Push

Chain the existing `git-commit` and `git-push` skills into one invocation, for the common case of wanting both done together instead of asking for them one at a time. (Bucket: Orchestration)

## Steps

1. Invoke the `git-commit` skill. It gathers status/diff/log itself, drafts a message, and commits — let it run its normal flow (including its own secret-file check) rather than re-doing any of that here.
2. If `git-commit` reports there was nothing to commit (clean working tree), say so and **stop** — do not proceed to a push. If, instead, the tree was clean but there are already-committed commits sitting unpushed (ahead of upstream), continue to step 3 anyway.
3. Invoke the `git-push` skill. It gathers its own status (branch, ahead-count) and handles its own confirm-or-skip decision — let it run its normal flow rather than re-confirming here.
4. Report back: the commit message used, and the push result (commits pushed, branch, remote URL) from `git-push`'s own report.
