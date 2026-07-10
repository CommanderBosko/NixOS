---
name: public-repo-guard
description: Run secret-scan then audit-config across the whole repo, triage every finding against a baseline allowlist of known-intentional items, and pass only when zero genuine findings remain — a pre-push / periodic safety guard for this public repo. Self-orchestrating loop. Use when the user says "/public-repo-guard", "run public-repo-guard", "is it safe to push", or "guard the public repo".
---

# Public Repo Guard — Loop

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

## Arguments

None — this loop always scans the whole repo (working tree and full git history), never a subset.

## Goal

Prove this **public** repo is safe to push: run `secret-scan` over the working tree and
full git history and `audit-config` over the entire flake, triage every finding against a
baseline allowlist of known-intentional items, and converge — run over run — on **zero
genuine findings**.

## Overall done-rule

`secret-scan` reports **no plaintext secret** outside the sops envelope, AND `audit-config`
reports **no genuine finding** that isn't already in
`.claude/loops/public-repo-guard/baseline-allowlist.md`. If any genuine, non-allowlisted
finding remains, the run is **blocked** — list it and do NOT push.

This loop is read-only with respect to the NixOS config — it never edits modules. It only
writes its two run files and (with my approval) appends to the baseline allowlist.

## Steps

For each step: read its done-rule FIRST. In Training Mode ON, if the done-rule already
passes, skip the step and tell me. Otherwise run it; if it fails, retry up to the cap,
then stop and report which step blocked.

1. **Load memory + baseline** — read the most recent `memory-*.md` in
   `.claude/loops/public-repo-guard/` AND the full
   `.claude/loops/public-repo-guard/baseline-allowlist.md`. Hold the allowlist in mind for
   triage in step 4.
   - Done-rule: both files read (memory may be absent; baseline must exist — if missing,
     stop and flag, it should be committed with this skill).

2. **Secret scan** — invoke the `secret-scan` skill: scan the working tree and full git
   history for plaintext secrets, tuned to this repo's sops setup.
   - Done-rule: scan completes and produces a (possibly empty) hit list. Treat
     sops-encrypted ciphertext as expected (per baseline), NOT a hit.

3. **Config audit** — invoke the `audit-config` skill: structured security + correctness
   pass over the ENTIRE flake (not just the diff), aware of this repo's intentional
   workarounds.
   - Done-rule: audit completes and produces a (possibly empty) findings list.

4. **Triage against baseline** — classify EVERY hit/finding from steps 2–3 as either
   **known-intentional** (matches an entry in `baseline-allowlist.md`) or **genuine**.
   In Training Mode ON, for anything you'd newly accept as intentional, pause and propose
   appending it to the baseline with a one-line justification; on my approval, append it.
   - Done-rule: every finding is classified; no finding is left "unknown". The baseline
     file reflects any newly-accepted items.

5. **Verdict** — count the genuine (non-allowlisted) findings.
   - Done-rule: count is **0** → safe to push. If > 0 → blocked; list each genuine finding
     with file/location and recommended fix, and stop (do NOT push).

## Verification plan

Before declaring the run done, prove the overall done-rule holds:
- `secret-scan` result contains no plaintext-secret hit outside the sops envelope.
- `audit-config` result contains no finding absent from `baseline-allowlist.md`.
- The genuine-findings count recorded in the Output file is exactly 0.
If any check fails, the run is NOT done (it's blocked) — record it in the Memory file,
list the genuine findings, and stop.

## End-of-run: write two files (ALWAYS)

Resolve `<today>` as the current date (YYYY-MM-DD). Write BOTH files into
`.claude/loops/public-repo-guard/`:

1. **Output** → `.claude/loops/public-repo-guard/output-<today>.md`
   The safety report: secret-scan summary, audit-config summary, the triage table
   (finding → intentional/genuine → allowlist ref or fix), and the final SAFE / BLOCKED
   verdict with the genuine-findings count.

2. **Memory** → `.claude/loops/public-repo-guard/memory-<today>.md`, with this shape:
   ```
   # public-repo-guard run — <today>

   - Mode: ON | OFF
   - Result: SAFE (0 genuine) | BLOCKED (<n> genuine) | blocked at step <n>
   - Steps skipped (already passed): <list>
   - Steps re-run: <list, with attempt counts>

   ## What worked
   - …

   ## What failed
   - …

   ## Remember next run
   - … (carry-forward notes: allowlist entries added this run, recurring false positives,
     a genuine finding still open)
   ```

   At the START of every run, read the most recent `memory-*.md` in this dir (if any)
   and apply its "Remember next run" notes before doing anything else.

## Report

Tell me: the mode, the verdict (SAFE / BLOCKED) and genuine-findings count, what was
triaged as intentional vs genuine, any allowlist entries added this run, where the two
files were written, and — if blocked — exactly what to fix before pushing.
