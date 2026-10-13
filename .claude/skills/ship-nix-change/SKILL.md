---
name: ship-nix-change
description: Run exactly the verification check(s) a NixOS config edit requires, then commit and push. Use when the user says "ship this nix change", "ship-nix-change", "verify and ship this config change", "run the right checks and commit this", or "verify then commit and push this nix change".
---

# Ship Nix Change

Chain the right verification skill(s) for whatever changed, then hand off to `commit-and-push` — replacing the by-hand reassembly of this same sequence every session. (Bucket: Orchestration)

## Why this exists

Shipping a NixOS config edit always needs the same shape of check-then-commit sequence, but which extra check applies depends on *what* changed — a host-local file only needs a local dry-run, a shared file needs the full 4-host sweep, an unwired DE module needs `de-smoke-check` instead. Reassembling this by hand each time is error-prone: one past session skipped the dry-run step entirely before committing. This skill makes the right chain automatic instead of re-derived from memory every time.

## Arguments

None — it operates on the current git diff/staged changes, not a user-supplied target.

## Steps

### 1. Resolve changed files and plan the checks

```bash
bash /home/bosko/NixOS/.claude/skills/ship-nix-change/scripts/plan-checks.sh
```

It combines the unstaged and staged file lists (`git diff --name-only` + `--cached`), classifies each file, and prints a `changed files` block and a `required checks` block (in run order). If it exits 1 (no changed files), say so plainly and stop — there is nothing to ship.

### 2. Always run the baseline local check

Invoke the `nixos-dry-run` skill. This is the mandatory first check regardless of what changed.

- If it fails, **stop immediately** and show the full error output verbatim — do not proceed to step 3 or commit anything.
- If it passes, continue to step 3.

### 3. Run any extra check the plan requires

Invoke each check step 1's `required checks` block lists after `nixos-dry-run`. The script classifies every file through `.claude/lib/classify-shared-file.sh` (reads `flake.nix` live) — don't re-derive this by hand (a hand-rolled check against just `commonModules`/`desktopModules` misses a module wired directly into 2+ hosts' own per-host lists, e.g. a DE module). What it lists:

- **`shared-module-check`** — any file classified `SHARED`. That skill re-resolves the changed-file impact itself (via the same classifier) and runs the full 4-host deep-eval sweep.
- **`de-smoke-check <name>`** — otherwise, one per changed `modules/desktop-environments/` module that no host currently imports.
- **Nothing extra** — only genuinely host-local files changed (e.g. `hosts/<host>/*`); the step 2 dry-run already covers it.

If step 3 invokes a check and it fails, **stop immediately** and report the failure verbatim (per that skill's own reporting convention, including per-host PASS/FAIL where applicable) — do not commit anything.

### 4. Commit and push

Once every check that applies has passed, invoke the `commit-and-push` skill to commit the changes and push them to the remote. Let it handle its own commit-message drafting, secret-file check, and push confirmation flow.

### 5. Report

Summarize:
- Which checks ran (dry-run always; plus `shared-module-check` or `de-smoke-check` if triggered) and their result
- Per-host PASS/FAIL if `shared-module-check` ran
- `commit-and-push`'s own report (commit message used, push result — commits pushed, branch, remote)

If anything stopped the chain early (step 2 or step 3 failure), make clear no commit was made and why.

## Scripts

- `scripts/plan-checks.sh [RANGE]` — read-only; prints the changed files with their classification and the required checks (steps 1 and 3). Exits 1 when nothing changed. `RANGE` (e.g. `HEAD~3..HEAD`) plans for already-committed changes instead of the working tree + index.
- `.claude/lib/classify-shared-file.sh <file>` — read-only classifier called by `plan-checks.sh`, shared with `shared-module-check` so the classification logic lives in exactly one place.
