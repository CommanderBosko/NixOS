<!-- BEGIN -->
```
---
name: <loop-name>
description: <one-sentence goal>. Self-orchestrating loop. Use when the user says "/<loop-name>", "run <loop-name>", or "<natural trigger phrase>".
---

# <Title Case Name> — Loop

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
> **Retry cap:** <N, default 3> attempts per failing step, then stop and report.

## Goal

<one-sentence goal — what a successful run produces or changes.>

## Overall done-rule

<the single condition that means this run succeeded. This is the verification bar.>

## Steps

For each step: read its done-rule FIRST. In Training Mode ON, if the done-rule already
passes, skip the step and tell me. Otherwise run it; if it fails, retry up to the cap,
then stop and report which step blocked.

1. **<Step 1 name>** — <what it does; exact command/tool/file>.
   - Done-rule: <how this step is known to pass — exit code / file exists / service active / text match>.
2. **<Step 2 name>** — <…>.
   - Done-rule: <…>.
<…more steps…>

## Verification plan

Before declaring the run done, prove the overall done-rule holds:
- <concrete check 1 — e.g. `nh os boot /home/bosko/NixOS --dry` evaluates clean, or `flake-check` passes>
- <concrete check 2 — host/service check, test run, lint, etc.>
If any check fails, the run is NOT done — record it in the Memory file and stop.

## End-of-run: write two files (ALWAYS)

Resolve `<today>` as the current date (YYYY-MM-DD). Write BOTH files into
`.claude/loops/<loop-name>/`:

1. **Output** → `.claude/loops/<loop-name>/output-<today>.md`
   The actual artifact this run produced (the document, code, or message).

2. **Memory** → `.claude/loops/<loop-name>/memory-<today>.md`, with this shape:
   ```
   # <loop-name> run — <today>

   - Mode: ON | OFF
   - Result: done | blocked at step <n>
   - Steps skipped (already passed): <list>
   - Steps re-run: <list, with attempt counts>

   ## What worked
   - …

   ## What failed
   - …

   ## Remember next run
   - … (carry-forward notes: gotchas, values, things to skip)
   ```

   At the START of every run, read the most recent `memory-*.md` in this dir (if any)
   and apply its "Remember next run" notes before doing anything else.

## Report

Tell me: the mode, the result, which steps were skipped vs re-run, where the two files
were written, and anything from "Remember next run" worth acting on.
```
<!-- END -->
