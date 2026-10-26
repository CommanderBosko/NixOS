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
   - **Pending CI checks** aren't a blocker here. Step 2 waits for them, so don't end the run just because CI hasn't finished.
   - **`UNKNOWN`** means GitHub hasn't computed mergeability yet. Re-run the script after a few seconds. Stacked children are only checked against their current base, so step 2 re-checks them after retargeting.
   - **`FORK:`** means several PRs stack on one parent. Their order is a decision for the user.

   Show the merge order (number, head -> base, title) and confirm it via **AskUserQuestion**, for example **Merge all in this order** (Recommended) / **Only the bottom PR** / **Cancel**. Ask before merging anything, because merging is outward-facing and can't be undone.

2. **Merge bottom-up, one PR per step.** For each PR in order:
   - **Wait for its CI checks first**: `/home/bosko/.claude/skills/land-prs/scripts/merge-step.sh wait N`. `main` is ruleset-protected, so merging with checks pending is refused. The script polls every 10 seconds until every check has finished, up to 540 seconds (CI takes about 2-3 minutes here). **Invoke it with the Bash tool's `timeout: 600000`.** The tool's default is 120000 ms, and a wait routinely outlives that, so without the explicit timeout the tool kills the call mid-wait with a timeout error. That error says nothing about CI, so don't read it as a pass or a fail. Run it as a foreground call (not `run_in_background`), and don't hand-roll a `sleep` loop. Interpret the exit code:
     - **Exit 0** (`checks passed`, or `no checks reported after 60s`): go on and merge. The 60-second grace covers a run that hasn't registered yet and only applies if no check was ever seen: once checks have appeared, an empty rollup counts as pending, not as done.
     - **Exit 1** (`failing checks: <names>`): stop and report. Don't merge a red PR or investigate unasked.
     - **Exit 3** (cap hit, checks still pending): ask via **AskUserQuestion**, **Keep waiting** (Recommended; re-run `wait N`, again with `timeout: 600000`) / **Stop here**.
     - **Exit 4** (`gh query failed 5 times in a row`, or the cap hit while the latest query was failing): the checks' state is unknown, so it is not "pending". Stop and report the `gh` error shown above that line (auth, network, API outage). Don't merge. Once the user has fixed it, re-run `wait N`.
   - Merge it, then confirm: `/home/bosko/.claude/skills/land-prs/scripts/merge-step.sh merge N`. It runs `gh pr merge N --merge`, then prints `<state> <sha>` from `gh pr view`. Expect `MERGED <sha>`. If you get anything else (the script exits 1), stop and report it. The script never passes `--delete-branch`. Branch cleanup waits until every PR has landed (steps 6–7).
   - If another PR follows, retarget it to `main` before merging it: `/home/bosko/.claude/skills/land-prs/scripts/merge-step.sh retarget <child>`. It runs `gh pr edit <child> --base main`, waits 3 seconds, and prints `<base> <mergeable> commits=K`. Expect `main MERGEABLE commits=K`, where K counts only the child's own commits. If you see `UNKNOWN`, or K still includes the parent's commits, re-check with `/home/bosko/.claude/skills/land-prs/scripts/merge-step.sh check <child>`. If you see `CONFLICTING`, stop and report it. Don't resolve conflicts unasked. The child's own `wait` happens at the top of its iteration, after this retarget.

3. **Confirm nothing is left open.** Run `gh pr list --state open` and check that no PR from the chain is still listed. Unrelated open PRs are fine.

4. **Verify the tree.** Run `git fetch -q && echo "origin/main=$(git rev-parse --short 'origin/main^{tree}') tip=$(git rev-parse --short '<tip-branch>^{tree}')"`. `<tip-branch>` is the last merged PR's head branch: the local branch if it exists, otherwise `origin/<tip-branch>`.
   - For a clean stack, the two trees match.
   - If they differ, for example because `main` moved on independently, show `git diff --stat <tip-branch> origin/main` and tell the user. Don't carry on silently.

5. **Sync local main.** Run `git checkout -q main && git merge -q --ff-only origin/main && git log --oneline --graph -8`. If the checkout fails because of uncommitted changes, or the fast-forward is refused because local `main` has diverged, stop and report. Never force it.

6. **Delete the merged branches locally.** Run `/home/bosko/.claude/skills/land-prs/scripts/merge-step.sh delete-local <branches>` with every chain head branch. It skips branches that don't exist locally and runs `git branch -d` on the rest. `-d` refuses unmerged branches. If it refuses one (the script exits 1), report it rather than escalating to `-D`.

7. **Delete the remote branches as a separate step.**
   - Check which branches still exist with `/home/bosko/.claude/skills/land-prs/scripts/merge-step.sh remote-heads <branches>` (read-only `git ls-remote --heads origin`). Skip any it lists as `already gone`, since the repo may auto-delete head branches after merge.
   - Confirm the remaining ones via **AskUserQuestion** with **Delete them** (Recommended) / **Keep them**.
   - If confirmed, run `/home/bosko/.claude/skills/land-prs/scripts/merge-step.sh delete-remote <branches>` (`git push origin --delete <branches>`) as its **own standalone Bash call**, never inside a longer `&&` chain (see Gotchas).
   - Finish with `/home/bosko/.claude/skills/land-prs/scripts/merge-step.sh prune` (`git fetch -q --prune && git branch -a`).

8. **Report back:**
   - each PR merged, with its merge-commit SHA
   - the tree-check result
   - where local `main` now sits (the step 5 log)
   - which branches were deleted, locally and on the remote, and which were skipped

## Gotchas

- **A remote branch delete chained with other commands can get the whole chain blocked by the auto-mode classifier.** Keep step 7's `delete-remote` in its own Bash call. The 2026-10-12 incident is in `references/gotchas.md`.

## Scripts

- `scripts/pr-chain.sh [N ...]` — read-only discovery for step 1. It prints the open PRs grouped into stacked chains in merge order (root first): number, head -> base, mergeable, a `DRAFT` marker, the title, and a `FORK:` line where two or more PRs stack on the same parent. With PR numbers, it prints only the chain(s) containing them. Exit codes: 0 ok (this includes "no open PRs"), 1 a requested PR isn't open, 2 usage error.
- `scripts/merge-step.sh <subcommand> ...` — one fixed step per call for steps 2, 6 and 7: `wait N [SECONDS]`, `merge N`, `retarget N`, `check N`, `delete-local B...`, `remote-heads B...`, `delete-remote B...`, `prune`. It never asks for confirmation; the AskUserQuestion gates stay in steps 1, 2 (a `wait` timeout) and 7. It refuses `main` or a `-`-prefixed name as a branch argument. Exit codes: 0 ok, 1 the step didn't reach its expected result (`wait` saw a failed check, `merge` not `MERGED`, or `delete-local` refused a branch), 2 usage error, 3 `wait` hit its cap with checks still pending, 4 `wait` couldn't read the checks because `gh` kept failing. Always call `wait` with the Bash tool's `timeout: 600000`, and keep its optional `SECONDS` at 540 or below so it ends inside that limit.
- `scripts/merge-step.test.sh` — self-contained test for `wait` (stubs `gh` through a PATH shim; takes about 10 seconds). Run it after editing the `wait` logic.
