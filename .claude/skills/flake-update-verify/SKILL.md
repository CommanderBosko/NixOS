---
name: flake-update-verify
description: Update flake inputs, prove the result still evaluates, then commit the flake.lock bump WITHOUT applying it — restoring the previous lock if the update breaks eval. Self-orchestrating loop. Use when the user says "/flake-update-verify", "run flake-update-verify", "update and verify the flake", or "bump inputs and check".
---

# Flake Update Verify — Loop

> ## ⚙️ Loop Training Mode: **ON**
> Flip this toggle by changing the line above to `OFF`. It changes how the loop runs:
>
> **When ON (default):**
> - Pause at **every step** and wait for my explicit approval before continuing.
> - **Skip** any step that already passes its done-rule (don't redo finished work).
> - Only **re-run steps that fail** their done-rule.
> - Respect the retry cap below — never loop forever.
>
> **When OFF:**
> - Run **autonomously**, no pauses.
> - Still run **every done-rule check** and still respect the **retry cap**.
> - ON-mode pauses need an interactive turn; use OFF for unattended/`/loop`-scheduled runs.
>
> **Retry cap:** 3 attempts per failing step, then stop and report.

## Goal

Bump all flake inputs in `/home/bosko/NixOS`, prove the updated `flake.lock` still
evaluates cleanly, and **commit the lock bump** with a readable change summary — but
**never** activate it (no `switch`/`boot`). If the update breaks evaluation, restore the
previous `flake.lock` so the tree is left building again.

## Overall done-rule

At end of run the working tree **evaluates clean**, and exactly one of:
- **Updated:** inputs changed, `flake-check` passes, and the `flake.lock` bump is
  committed (no `switch`/`boot` performed); **or**
- **Nothing to do:** `nix flake update` produced no `flake.lock` change; **or**
- **Reverted:** the update broke eval and `flake.lock` was restored to its previous,
  evaluating state — with the offending input named in the report.

Applying the update is explicitly **out of scope** — that's `/fleet-rollout`.

## Steps

For each step: read its done-rule FIRST. In Training Mode ON, if the done-rule already
passes, skip the step and tell me. Otherwise run it; if it fails, retry up to the cap,
then stop and report which step blocked.

1. **Load carry-forward memory** — read the most recent `memory-*.md` in
   `.claude/loops/flake-update-verify/` and apply its "Remember next run" notes (e.g. an
   input known to break, a pin to respect).
   - Done-rule: latest memory file read (or confirmed none exists).

2. **Pre-flight: clean working tree** — so the only change after the update is
   `flake.lock`. Run `git -C /home/bosko/NixOS status --porcelain`.
   - Done-rule: output empty. If dirty, stop and ask me to commit/stash first — do NOT
     update on top of unrelated changes.

3. **Snapshot the current lock** — capture the pre-update lock for a clean restore path:
   note it is recoverable via `git -C /home/bosko/NixOS checkout -- flake.lock` (the tree
   is clean per step 2, so git is the source of truth).
   - Done-rule: `flake.lock` is tracked and committed (so checkout can restore it).

4. **Update inputs** — invoke the `update` skill (`nix flake update`) and capture its
   readable summary of what changed in `flake.lock`.
   - Done-rule: `nix flake update` exits 0. If `git status --porcelain flake.lock` is
     empty afterward, there were **no updates** → record "Nothing to do" and jump to the
     report (overall done-rule satisfied).

5. **Verify the updated lock evaluates** — invoke the `flake-check` skill
   (`nix flake check`) to evaluate ALL host configs against the new inputs; optionally
   also run `nixos-dry-run` for the local host's toplevel.
   - Done-rule: `flake-check` completes with no evaluation errors.
   - **On failure:** restore the lock with `git -C /home/bosko/NixOS checkout -- flake.lock`,
     identify which input bump broke eval (bisect/inspect the diff), record "Reverted",
     and stop. Do NOT commit. (If I want to keep most updates, `pin-input` can hold back
     just the offender — mention it, don't run it.)

6. **Commit the lock bump (success path only)** — on clean `flake-check`, commit ONLY
   `flake.lock` via the `commit` skill with a conventional message like
   `chore(flake): bump inputs <YYYY-MM-DD>` summarizing the changed inputs in the body.
   - Done-rule: `git log -1 --name-only` shows a new commit touching `flake.lock` and the
     working tree is clean again. **No `switch`/`boot` was run.**

## Verification plan

Before declaring the run done, prove the overall done-rule holds:
- `nix flake check` (the `flake-check` skill) passes against the final tree state.
- `git -C /home/bosko/NixOS status --porcelain` is empty (either committed or restored —
  never left dirty).
- Confirm no activation happened: no `nh os switch` / `nixos-rebuild switch` was invoked.
If any check fails, the run is NOT done — record it in the Memory file and stop.

## End-of-run: write two files (ALWAYS)

Resolve `<today>` as the current date (YYYY-MM-DD). Write BOTH files into
`.claude/loops/flake-update-verify/`:

1. **Output** → `.claude/loops/flake-update-verify/output-<today>.md`
   The change report: which inputs moved (old rev → new rev), the eval verdict, and the
   final state (committed / nothing-to-do / reverted-with-offender).

2. **Memory** → `.claude/loops/flake-update-verify/memory-<today>.md`, with this shape:
   ```
   # flake-update-verify run — <today>

   - Mode: ON | OFF
   - Result: done (committed) | done (nothing to do) | reverted | blocked at step <n>
   - Steps skipped (already passed): <list>
   - Steps re-run: <list, with attempt counts>

   ## What worked
   - …

   ## What failed
   - …

   ## Remember next run
   - … (carry-forward notes: an input that broke eval, a pin in effect, the commit sha)
   ```

   At the START of every run, read the most recent `memory-*.md` in this dir (if any)
   and apply its "Remember next run" notes before doing anything else.

## Report

Tell me: the mode, the result (committed / nothing-to-do / reverted), the per-input
old→new summary, the eval verdict, where the two files were written, and — if reverted —
which input broke eval and that `/fleet-rollout` is the way to apply once it's healthy.
