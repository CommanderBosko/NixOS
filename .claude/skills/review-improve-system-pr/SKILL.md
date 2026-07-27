---
name: review-improve-system-pr
description: Review and (with confirmation) merge the PR the weekly improve-system cloud routine opens. Use when the user says "review the improve-system PR", "check the weekly PR", "review-improve-system-pr", "handle the Sunday PR", or "is there an improve-system PR to merge".
---

# Review Improve-System PR

Find the PR the weekly `improve-system` cloud routine opened, verify it stayed inside its auto-apply guardrail, then merge it only after explicit user confirmation. (Bucket: Orchestration — chains a guardrail check, a diff review, an AskUserQuestion gate, and a merge; each step stands alone but the chain matters so the gate never gets skipped under time pressure.)

## Steps

### 1. Find the PR and check the guardrail

Run `scripts/find-and-check-pr.sh` (relative to this skill's directory). It finds the open PR from the routine (title `chore(skills): weekly improve-system sweep`, or head branch `improve-system/weekly-*`) and checks every changed file against the routine's auto-apply boundary: path under `.claude/skills/` or `dotfiles/bosko/claude/skills/`, and either named `SKILL.md` or under a `scripts/`/`assets/` subdirectory.

Interpret the exit code:
- **1 (no PR found)** — this is a normal, expected outcome most weeks. Report "nothing to review" and stop here.
- **2 (guardrail violation)** — a changed file falls outside the boundary (e.g. touches a `.nix` file, or a path outside those two skill dirs). Stop. Do not proceed to merge. Report the PR number and the offending file(s) to the user as needing manual review, and explain why the script flagged it.
- **0 (OK)** — guardrail holds. Continue to step 2.

### 2. Show the diff

Run `gh pr diff <number> --repo CommanderBosko/NixOS` and summarize it in plain language for the user: what changed, in which skill(s), and why (the script's `PR_BODY` output should state the findings the routine fixed — surface that reasoning, don't just dump the raw diff).

### 3. Confirm before merging

Gate via **AskUserQuestion**: "Merge this PR" (recommended, once the diff looks sound) vs "Hold off, I'll review manually". Never merge without this explicit checkpoint — these are AI-generated changes to the skill files this user relies on every session, and the guardrail check in step 1 only proves the PR touched the *right files*, not that the *content* is correct.

- **Hold off** — stop cleanly. Report the PR number and URL for the user to review later themselves.
- **Merge this PR** — continue to step 4.

### 4. Merge

Run `gh pr merge <number> --squash --repo CommanderBosko/NixOS` (matches the squash-merge convention already used for this routine's PRs).

Remind the user: for skills under `dotfiles/bosko/claude/skills/` (repo-managed/global scope), the `~/.claude/skills/<name>/` symlink only reflects this merge after `nh os boot /home/bosko/NixOS` **+ reboot** — the repo copy is current immediately, but the live symlinked skill isn't until then. Skills under `.claude/skills/` (project-local) are live immediately.

### 5. Report

Report: the PR number, files changed, and the outcome — merged / held for manual review (guardrail violation) / held for manual review (user chose to hold off) / nothing to review.

## Scripts

- `.claude/skills/review-improve-system-pr/scripts/find-and-check-pr.sh` — finds the open weekly improve-system PR and checks its changed files against the auto-apply guardrail; read-only, exit 0/1/2 as described in Step 1.
