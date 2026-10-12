---
name: land-prs
description: Merge an open GitHub PR, or a stacked chain of PRs, bottom-up with merge commits — retargeting each child to main as its parent lands, verifying main's final tree, fast-forwarding local main, and cleaning up the merged branches. Use when the user says "merge the PRs", "land this PR", "merge the stack", "land the PR chain", or "land-prs".
---

# Land PRs

Land one open PR or a stacked chain of them on `main` with merge commits, then verify the result and clean up the merged branches. (Bucket: Utility)

## Arguments

- **PR number(s)** (optional), e.g. `land-prs 4` or `land-prs 2 3 4`. With none, discover every open PR and its stack.

## Steps

1. **Discover the chain.** Run `/home/bosko/.claude/skills/land-prs/scripts/pr-chain.sh [N ...]`. It wraps `gh pr list --state open --json number,title,headRefName,baseRefName,mergeable,isDraft` and prints each chain in merge order, root first. A PR whose base is another open PR's head is stacked on it. Interpret the output:
   - **Exit 1** means a requested PR isn't open. Report it, and continue only with the PRs that are open.
   - **A requested PR in the middle of a chain** needs its ancestors merged first. Merging it against its current base would land it on the parent's branch, not `main`. Its descendants are left alone unless the user named them too.
   - **`CONFLICTING` or `DRAFT`** on a PR you plan to merge means it can't land. Report it and stop.
   - **`UNKNOWN`** means GitHub hasn't computed mergeability yet. Re-run the script after a few seconds. Stacked children are only checked against their current base, so step 2 re-checks them after retargeting.
   - **`FORK:`** means several PRs stack on one parent. Their order is a decision for the user.

   Show the merge order (number, head -> base, title) and confirm it via **AskUserQuestion**, for example **Merge all in this order** (Recommended) / **Only the bottom PR** / **Cancel**. Ask before merging anything, because merging is outward-facing and can't be undone.

2. **Merge bottom-up, one PR per step.** For each PR in order:
   - Merge it, then confirm: `gh pr merge N --merge && gh pr view N --json state,mergeCommit --jq '.state+" "+.mergeCommit.oid[0:7]'`. Expect `MERGED <sha>`. If you get anything else, stop and report it. Don't pass `--delete-branch`. Branch cleanup waits until every PR has landed (steps 6–7).
   - If another PR follows, retarget it to `main` before merging it: `gh pr edit <child> --base main && sleep 3 && gh pr view <child> --json baseRefName,mergeable,commits --jq '.baseRefName+" "+.mergeable+" commits="+(.commits|length|tostring)'`. Expect `main MERGEABLE commits=K`, where K counts only the child's own commits. If you see `UNKNOWN`, or K still includes the parent's commits, re-run the `gh pr view`. If you see `CONFLICTING`, stop and report it. Don't resolve conflicts unasked.

3. **Confirm nothing is left open.** Run `gh pr list --state open` and check that no PR from the chain is still listed. Unrelated open PRs are fine.

4. **Verify the tree.** Run `git fetch -q && echo "origin/main=$(git rev-parse --short 'origin/main^{tree}') tip=$(git rev-parse --short '<tip-branch>^{tree}')"`. `<tip-branch>` is the last merged PR's head branch: the local branch if it exists, otherwise `origin/<tip-branch>`.
   - For a clean stack, the two trees match.
   - If they differ, for example because `main` moved on independently, show `git diff --stat <tip-branch> origin/main` and tell the user. Don't carry on silently.

5. **Sync local main.** Run `git checkout -q main && git merge -q --ff-only origin/main && git log --oneline --graph -8`. If the checkout fails because of uncommitted changes, or the fast-forward is refused because local `main` has diverged, stop and report. Never force it.

6. **Delete the merged branches locally.** Run `git branch -d <branches>` for each chain head branch that exists locally (`git branch --list <branches>`). `-d` refuses unmerged branches. If it refuses one, report it rather than escalating to `-D`.

7. **Delete the remote branches as a separate step.**
   - Check which branches still exist with `git ls-remote --heads origin <branches>`. Skip any that are already gone, since the repo may auto-delete head branches after merge.
   - Confirm the remaining ones via **AskUserQuestion** with **Delete them** (Recommended) / **Keep them**.
   - If confirmed, run `git push origin --delete <branches>` as its **own standalone Bash call**, never inside a longer `&&` chain (see Gotchas).
   - Finish with `git fetch -q --prune && git branch -a`.

8. **Report back:**
   - each PR merged, with its merge-commit SHA
   - the tree-check result
   - where local `main` now sits (the step 5 log)
   - which branches were deleted, locally and on the remote, and which were skipped

## Gotchas

- **A `git push origin --delete` inside an `&&` chain gets the whole chain blocked.** Seen on 2026-10-12 in blueprint-smith, after PRs #2–#4 had landed. One chain held the tree check, the checkout, the fast-forward, the remote delete, `git branch -d` and the prune. The Claude Code auto-mode classifier denied all of it as `[Git Destructive]`, so even the safe steps didn't run. It had to be rerun without the deletes. A similar bundle for PR #1 had gone through in an earlier session, so you can't predict when the block will hit. The reliable fix is to give the remote delete its own confirmed Bash call (step 7).

## Scripts

- `scripts/pr-chain.sh [N ...]` — read-only discovery for step 1. It prints the open PRs grouped into stacked chains in merge order (root first): number, head -> base, mergeable, a `DRAFT` marker, the title, and a `FORK:` line where two or more PRs stack on the same parent. With PR numbers, it prints only the chain(s) containing them. Exit codes: 0 ok (this includes "no open PRs"), 1 a requested PR isn't open, 2 usage error.
