---
name: review-improve-system-pr
description: Review and (with confirmation) merge the PR the weekly improve-system cloud routine opens. Use when the user says "review the improve-system PR", "check the weekly PR", "review-improve-system-pr", "handle the Sunday PR", or "is there an improve-system PR to merge".
---

# Review Improve-System PR

Find the PR the weekly `improve-system` cloud routine opened, verify it stayed inside its auto-apply guardrail, then merge it only after explicit user confirmation. (Bucket: Orchestration — chains a guardrail check, a diff review, an AskUserQuestion gate, and a merge; each step stands alone but the chain matters so the gate never gets skipped under time pressure.)

## Arguments

None — the target is always whichever open PR the weekly `improve-system` routine most
recently opened (resolved automatically in Step 1).

## Steps

### 1. Find the PR and check the guardrail

Run `.claude/skills/review-improve-system-pr/scripts/find-and-check-pr.sh` (repo-root-relative — a bare `scripts/...` path 404s from the actual Bash-tool cwd). It finds the open PR from the routine by head branch (`improve-system/weekly-*` — the routine's PR titles have already drifted once between runs, so the branch name is the only stable match) and checks every changed file against the routine's auto-apply boundary: path under `.claude/skills/` or `dotfiles/bosko/claude/skills/`, and either named `SKILL.md` or under a `scripts/`/`assets/`/`references/` subdirectory. The one exception is `.claude/settings.json`, which passes only when the PR purely adds entries to `permissions.allow` (no removals, no deny/ask/hooks edits) and every added entry **passes the read-only allowlist** in `check-settings-diff.sh`: default-deny, so only an exact-shape match for a short read-only form is accepted — read-only `git`/`gh`/`nix`/`systemctl`/`flatpak` subcommands, metadata-only inspectors (`ls`, `df`, `journalctl`, ...), a concrete `.claude/.../scripts/*.sh` file, or an MCP tool whose name starts with a whole read-verb word (`get_`, `list_`, ... — not `getaway`) and contains no write verb, no `_and_`/`_or_`/`_then_` chain and no credential word (`secret`, `token`, `password`, `api key`, `oauth`, ...). Everything else (any other command, global flags before a subcommand, double spaces, a mid-string `*`, a `*` glued to a word such as `ls*` or `git diff*` — write ` *` with a space, or an exact command — whole-server `mcp__<server>`, credential paths) is refused. Only added entries are judged: existing glued-`*` entries in `settings.json` keep working untouched. On a pass the script lists the entries under `SETTINGS_ALLOW_ADDED:`, so surface those in Step 2. Even a passing allow entry widens what runs without a prompt (a `*` rule matches any arguments, and a script entry runs whatever the script contains), so read each one and say so — "the guardrail passed" is not "these are safe".

Three more rules turn a changed file into a violation, each printed with its reason next to the file: (1) **the gate and its boundary** — anything under `review-improve-system-pr/` or `improve-system/` (either skills root), so a PR this gate approves can never loosen the gate; (2) **a script `settings.json` already runs without a prompt** — every repo path mentioned in a settings string at the PR base (allow entries and hook commands) plus the entries the PR adds, with `bash `, `~/.claude/...` / `"$HOME"/.claude/...` (mapped to `dotfiles/bosko/claude/...`), `$CLAUDE_PROJECT_DIR/...`, bare `dotfiles/bosko/claude/...` and absolute `/home/bosko/NixOS/...` forms normalised, and a glued trailing `*` counted as a prefix — which also catches a PR that adds a script together with an allow entry for it; (3) **shared libs** those scripts source (`.claude/lib/`, `.claude/skills/lib/`, `dotfiles/bosko/claude/skills/lib/`). A renamed file is checked under its old name too (REST `previous_filename`), `.claude/settings.json` included.

The script also prints `PR_HEAD_SHA:` — the exact commit it checked. Keep that SHA; Step 4 pins the merge to it.

Interpret the exit code:
- **1 (no PR found)** — this is a normal, expected outcome most weeks. Report "nothing to review" and stop here. (Only a clean `gh` response gets exit 1; a `gh` failure is exit 3, never "no PR".)
- **2 (guardrail violation)** — a changed file falls outside the boundary (e.g. touches a `.nix` file, or a path outside those two skill dirs, or a `settings.json` allow entry the second-pass check refused), or it is one of the gate/improve-system files, a script `settings.json` runs unprompted, or a shared lib (rules above). Stop. Do not proceed to merge. Report the PR number and the offending file(s) with the printed reason to the user as needing manual review. Exit 2 means "a human must read this", not "forbidden" — over-flagging is intended, and a human may still approve the change after reading it.
- **3 (could not evaluate)** — `gh` failed (auth, network, API — including fetching `settings.json` at the PR base, which is now always needed and must hold a `permissions.allow` array, or the rename list) or returned data the script would not trust (no files, a file list that may be truncated, an invalid `REVIEW_SAFE_HOME`). The guardrail was **not** checked and no `GUARDRAIL: OK` was printed. Stop. Report the `ERROR:` line verbatim and suggest `gh auth status`; never describe this as "nothing to review" or retry past it by hand.
- **0 (OK)** — guardrail holds. Continue to step 2.

### 2. Show the diff

Run `gh pr diff <number> --repo CommanderBosko/NixOS` and summarize it in plain language for the user: what changed, in which skill(s), and why (the script's `PR_BODY` output should state the findings the routine fixed — surface that reasoning, don't just dump the raw diff).

### 3. Confirm before merging

Gate via **AskUserQuestion**: "Merge this PR once CI is green" (recommended, once the diff looks sound) vs "Hold off, I'll review manually". Never merge without this explicit checkpoint — these are AI-generated changes to the skill files this user relies on every session, and the guardrail check in step 1 only proves the PR touched the *right files*, not that the *content* is correct. A confirmation covers only the commit you showed (`PR_HEAD_SHA`) and is conditional on CI passing.

- **Hold off** — stop cleanly. Report the PR number and URL for the user to review later themselves.
- **Merge this PR** — continue to step 4.

### 4. Wait for CI, then merge

1. **Wait for CI** with the gate script, as its own Bash call with an explicit `timeout: 600000` (the `flake check` deep-eval job normally takes ~2-3 minutes; the script waits at most 570s itself so it ends before the Bash limit), passing the `PR_HEAD_SHA` from Step 1:

   ```bash
   .claude/skills/review-improve-system-pr/scripts/ci-gate.sh <number> <PR_HEAD_SHA>
   ```

   It runs `gh pr checks --watch --fail-fast` and also requires that the PR head still equals the reviewed SHA, before and after the wait. Only **exit 0** (`CI_GATE: PASS`) lets you continue. Exit 1 (a check failed, none reported, or gh errored), 8 (still pending), 3 (could not evaluate) or 4 (head moved — the reviewed commit is no longer the PR head) mean **stop without merging**: report the script's last line and the check link, and leave the PR for the user (after exit 4, re-run from Step 1). Do not retry into a merge and do not offer to merge past a red, missing or unevaluated CI; the user can merge it themselves. (`land-prs` has no CI wait of its own, so this step is the only gate.)

2. **Merge, pinned to the reviewed commit**, using the same `PR_HEAD_SHA` from Step 1 (never re-read the head SHA from GitHub here — that would pin to whatever is there now, including a commit pushed after you reviewed):

   ```bash
   gh pr merge <number> --squash --match-head-commit <PR_HEAD_SHA> --repo CommanderBosko/NixOS
   ```

   Squash matches the convention already used for this routine's PRs. If GitHub refuses because the head moved, **stop**: the PR changed after the guardrail check and diff review, so re-run from Step 1 instead of retrying without the pin.

3. **Confirm it landed:** `gh pr view <number> --repo CommanderBosko/NixOS --json state,mergeCommit --jq '.state + " " + .mergeCommit.oid[0:7]'` should print `MERGED <sha>`; report anything else as a failure.

Remind the user: for skills under `dotfiles/bosko/claude/skills/` (repo-managed/global scope), the `~/.claude/skills/<name>/` symlink only reflects this merge after `nh os boot /home/bosko/NixOS` **+ reboot** — the repo copy is current immediately, but the live symlinked skill isn't until then. Skills under `.claude/skills/` (project-local) are live immediately.

### 5. Report

Report: the PR number, files changed, and the outcome — merged (with the merge SHA) / held for manual review (guardrail violation) / not evaluated (gh failure, exit 3) / held back (CI not green, or the head moved since review) / held for manual review (user chose to hold off) / nothing to review.

## Scripts

- `.claude/skills/review-improve-system-pr/scripts/find-and-check-pr.sh` — finds the open weekly improve-system PR and checks its changed files against the auto-apply guardrail; read-only, exit 0/1/2/3 as described in Step 1, and prints `PR_HEAD_SHA:` for Step 4's merge pin.
- `.claude/skills/review-improve-system-pr/scripts/check-settings-diff.sh <base.json> <head.json>` — called by the script above; decides whether a `.claude/settings.json` change is purely additive to `permissions.allow` and free of over-broad or high-power entries. Pure local check, exit 0 (prints `ADDED:` lines) or 1 (prints `REASON:`).
- `.claude/skills/review-improve-system-pr/scripts/ci-gate.sh <pr-number> <head-sha>` — Step 4's merge gate: waits for the PR's checks and requires the head to still equal the reviewed SHA. Read-only; exit 0 pass / 1 failed or none / 2 usage / 3 not evaluated / 4 head moved / 8 pending.
- `.claude/skills/review-improve-system-pr/scripts/find-and-check-pr.test.sh [target]` — offline tests (stub `gh`) for the file guardrail; run it after any edit to `find-and-check-pr.sh`. Pass an older copy as `target` for a mutation check (cases tagged `[new]` should fail there).
- `.claude/skills/review-improve-system-pr/scripts/check-settings-diff.test.sh [target]` — offline tests for the allow-entry checker (the 84-entry refusal list, the benign list, glued-`*` and MCP-name cases, and the real `settings.json`); same `[regress]`/`[new]` mutation convention.

## Gotchas

- Run Step 2's `gh pr diff` without a multi-file pathspec — it accepts at most one path after `--` (see `references/gotchas.md`).
- Run Step 4's `ci-gate.sh` as its own Bash call with `timeout: 600000`; the default 120000ms ends the wait mid-run, and anything but exit 0 is "not green", not "probably fine".
- This skill's own files (and `improve-system`'s) are on the exit-2 denylist: editing this gate always needs a human, even when the PR looks like a harmless doc fix. Land such changes through a normal PR, not the weekly routine.
- `check-settings-diff.sh` is a default-deny allowlist, not a proof of safety. A refusal means "a human reviews this entry" (many harmless commands are refused on purpose); a pass still needs the Step 2 read-through (see `references/gotchas.md`).
