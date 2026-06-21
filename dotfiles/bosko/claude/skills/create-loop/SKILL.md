---
name: create-loop
description: Create a custom, self-orchestrating loop skill from an interview — bakes a task's goal, ordered steps, and done-rule into a one-command runnable loop with Loop Training Mode, dual-file (Output + Memory) output, retry caps, and a built-in verification plan. Use when the user says "create a loop", "/create-loop", "make a loop", "build a loop skill", "turn this task into a loop", or "I want a loop that does X".
---

# Create Loop — Loop Orchestrator Generator

Interview the user, then generate a **project-local, self-orchestrating loop skill** they can run with one command (`/<loop-name>`). Each generated loop carries its own goal, ordered steps, per-step done-rules, **Loop Training Mode**, a retry cap, dual-file output (the artifact + a memory log), and a built-in verification plan.

This is a *meta-skill*: it writes other skills. It does **not** run the loop itself — it produces the loop file and verifies that file is well-formed.

## Key facts (don't re-derive these)

- **Generated loops are project-local:** `<repo-root>/.claude/skills/<loop-name>/SKILL.md`. Immediately runnable, no rebuild, committed with the project.
- **`/create-loop` itself is global/repo-owned** (lives under `dotfiles/bosko/claude/skills/create-loop/`, symlinked via `bosko-claude.nix`). You are editing/using that copy now; do not touch the read-only `~/.claude` symlink.
- **Per-run output dir:** `<repo-root>/.claude/loops/<loop-name>/` holds `output-<date>.md` and `memory-<date>.md` for every run.
- **Retry cap default:** 3 attempts per step (configurable per loop).
- **Loop Training Mode default:** ON.

## Steps

### 1. Interview for the loop's spec

Ask these together as a numbered list. Pre-fill anything the user already gave and confirm rather than re-asking.

1. **Goal** — one sentence: what does a successful run produce or change?
2. **Loop name** — derive a short kebab-case name from the goal (e.g. `weekly-flake-audit`, `draft-release-notes`). Confirm.
3. **Ordered steps** — the workflow as a numbered list. For each step capture: what it does, the exact command/tool/file involved, and **its own done-rule** (how *that step* is known to pass).
4. **Overall done-rule** — the single condition that means the whole loop succeeded this run (this is the loop's verification bar).
5. **Output artifact** — what the loop actually produces (a doc, code, a message, a report). This becomes `output-<date>.md`.
6. **Retry cap** — attempts per failing step before the loop gives up (default **3**).
7. **Training Mode default** — confirm **ON** unless the user overrides.

If the goal is fuzzy, push for concreteness before generating — a vague done-rule produces a loop that never knows when it's finished.

### 2. Offer a workspace scan (built-in capability)

Offer to scan the current repo for repeatable, loop-worthy tasks before or instead of a from-scratch spec:

> "Want me to scan this workspace for tasks you do repeatedly that would make good loops?"

If yes: look at `CLAUDE.md`, existing `.claude/skills/`, recent git history, and any session/close docs for multi-step tasks that recur. For each candidate, propose a one-line loop spec: **task → your preference → what counts as done**. Let the user pick which to generate. If no, proceed with the interview spec from step 1.

### 3. Generate the loop skill from the template

Write `<repo-root>/.claude/skills/<loop-name>/SKILL.md` using the **Generated Loop Template** below. Fill every `<…>` placeholder from the interview. Keep the Training Mode block verbatim — it is the contract.

Create `.claude/skills/` and `.claude/loops/<loop-name>/` with `mkdir -p` if they don't exist.

### 4. Verify the generated loop (built-in verification plan)

Before handing off, prove the loop file is well-formed:

1. **Frontmatter & structure** — confirm the file has valid `name:`/`description:` frontmatter, a Training Mode block at the top set to ON, the numbered steps, the done-rules, the retry cap, and the dual-file output section. Read it back.
2. **Name match** — confirm `name:` in frontmatter matches the directory name (Claude Code requires this for the slash command to resolve).
3. **Dry verification of the loop's own checks** — read each step's done-rule and confirm it's something Claude Code can actually evaluate (a command exit code, a file existing, a service being active, text matching). Flag any done-rule that's unmeasurable.
4. **One verification pass** — auto-run the generated loop's *verification step only* once (not the full mutating loop) to confirm the done-rule machinery resolves. Report the result.
5. Run `ls -la <repo-root>/.claude/skills/<loop-name>/` to confirm the file exists.

### 5. Offer to commit

After verification passes, offer to commit the new loop (the generated SKILL.md plus the `.claude/loops/<loop-name>/` dir). Draft a conventional commit message and commit immediately on yes — don't ask for line-by-line approval.

### 6. Confirm and hand off

Tell the user:
- The loop name and full path written.
- The exact command to run it: `/<loop-name>`.
- That Training Mode is **ON by default** and where the toggle is (top of the file).
- That it's runnable immediately (project-local, no rebuild), and can be wrapped by the built-in `/loop` for interval scheduling (`/loop /<loop-name>`).
- Where per-run files land: `.claude/loops/<loop-name>/output-<date>.md` and `memory-<date>.md`.

---

## Generated Loop Template

Write this to `<repo-root>/.claude/skills/<loop-name>/SKILL.md`, substituting placeholders. **Everything between the `<!-- BEGIN -->` and `<!-- END -->` markers is the file content** (do not include the markers themselves).

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

## Gotchas

- **Project-local skills resolve immediately** — no rebuild needed for the *generated* loop. Only `/create-loop` itself (being global/repo-owned) needs a rebuild to update.
- **`name:` must equal the directory name**, or `/<loop-name>` won't resolve.
- **Done-rules must be machine-checkable.** If the user gives a vague one ("looks good"), push back and turn it into something with an exit code, a file check, or a text match — otherwise Training Mode's "skip if passing" can't work.
- **ON-mode is interactive only.** Don't promise unattended pauses; tell the user to flip to OFF for `/loop`-scheduled or background runs.
