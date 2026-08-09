---
name: create-loop
description: Create a custom, self-orchestrating loop skill from an interview — bakes a task's goal, ordered steps, and done-rule into a one-command runnable loop with Loop Training Mode, dual-file (Output + Memory) output, retry caps, and a built-in verification plan. Use when the user says "create a loop", "/create-loop", "make a loop", "build a loop skill", "turn this task into a loop", or "I want a loop that does X".
---

# Create Loop — Loop Orchestrator Generator

Interview the user, then generate a **project-local, self-orchestrating loop skill** they can run with one command (`/<loop-name>`). Each generated loop carries its own goal, ordered steps, per-step done-rules, **Loop Training Mode**, a retry cap, dual-file output (the artifact + a memory log), and a built-in verification plan.

This is a *meta-skill*: it writes other skills. It does **not** run the loop itself — it produces the loop file and verifies that file is well-formed.

## Arguments

Parse from the user's invocation phrase, if given:

- **Goal** — a one-sentence description of what a successful run produces or changes, if stated (e.g. "a loop that drafts release notes every Friday").
- **Loop name** — a proposed kebab-case name, if the user names it directly.
- **Steps** — any workflow detail already volunteered (commands, files, decisions).

Pre-fill Step 1's interview questions from whatever is already given, and confirm rather than re-asking. Only ask for what's still missing.

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
8. **Model tier** — classify the loop's dominant per-run work: **grunt** (fixed commands, fetch/format/relay, deterministic pass/fail against fixed criteria) → pin `model: haiku` in the generated frontmatter; **judgment** (synthesis, deciding what to do next, drafting non-trivial content, evaluating tradeoffs) → leave `model:` unset so it inherits the session's top model. If mixed, default to leaving it unset.

If the goal is fuzzy, push for concreteness before generating — a vague done-rule produces a loop that never knows when it's finished.

### 2. Offer a workspace scan (built-in capability)

Before or instead of a from-scratch spec, use the **AskUserQuestion** tool to offer a workspace scan for repeatable, loop-worthy tasks, with options **Scan** (scan the workspace for loop-worthy tasks) and **Skip** (proceed straight to the interview spec from step 1).

If **Scan**: look at `CLAUDE.md`, existing `.claude/skills/`, recent git history, and any session/close docs for multi-step tasks that recur. For each candidate, propose a one-line loop spec: **task → your preference → what counts as done**. Let the user pick which to generate. If **Skip**, proceed with the interview spec from step 1.

### 3. Generate the loop skill from the template

Write `<repo-root>/.claude/skills/<loop-name>/SKILL.md` using the **Generated Loop Template** below. Fill every `<…>` placeholder from the interview. Keep the Training Mode block verbatim — it is the contract. If step 1's model tier came out **grunt**, add a `model: haiku` line directly after `description:` in the generated frontmatter; if **judgment**, leave the frontmatter as the template has it (no `model:` field).

Create `.claude/skills/` and `.claude/loops/<loop-name>/` with `mkdir -p` if they don't exist.

### 4. Verify the generated loop (built-in verification plan)

Before handing off, prove the loop file is well-formed:

1. **Structural lint (mechanical, scripted)** — run (absolute path — a bare `scripts/...`
   path 404s, this is a global home-symlinked skill and the Bash tool's cwd is the project
   root, not this skill's directory):
   ```bash
   /home/bosko/.claude/skills/create-loop/scripts/lint-loop.sh <repo-root>/.claude/skills/<loop-name>/SKILL.md
   ```
   It checks presence/shape only (never meaning): valid `name:`/`description:` frontmatter,
   `name:` matching the directory name (required for the slash command to resolve), the
   Training Mode block, retry cap, Goal/Overall-done-rule/Steps/Verification-plan/Report
   sections, at least one step `Done-rule:`, and the dual-file Output/Memory section. Fix
   anything it FAILs before continuing — don't hand-check these by eye.
2. **Dry verification of the loop's own checks (judgment, not scriptable)** — read each
   step's done-rule and confirm it's something Claude Code can actually evaluate (a command
   exit code, a file existing, a service being active, text matching). Flag any done-rule
   that's unmeasurable.
3. **One verification pass** — auto-run the generated loop's *verification step only* once
   (not the full mutating loop) to confirm the done-rule machinery resolves. Report the
   result.

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

The loop file content lives verbatim in `assets/loop-template.md` — it is the contract, kept byte-faithful and out of this prose. To generate a loop:

1. **Read** `assets/loop-template.md` (relative to this skill's directory).
2. Inside that asset, **everything between the `<!-- BEGIN -->` and `<!-- END -->` markers is the file content** (do not include the markers themselves) — substitute every `<…>` placeholder from the interview, keeping the Training Mode block verbatim.
3. **Write** the filled result to `<repo-root>/.claude/skills/<loop-name>/SKILL.md`.

## Gotchas

- **Project-local skills resolve immediately** — no rebuild needed for the *generated* loop. Only `/create-loop` itself (being global/repo-owned) needs a rebuild to update.
- **`name:` must equal the directory name**, or `/<loop-name>` won't resolve.
- **Done-rules must be machine-checkable.** If the user gives a vague one ("looks good"), push back and turn it into something with an exit code, a file check, or a text match — otherwise Training Mode's "skip if passing" can't work.
- **ON-mode is interactive only.** Don't promise unattended pauses; tell the user to flip to OFF for `/loop`-scheduled or background runs.

## Scripts

- `/home/bosko/.claude/skills/create-loop/scripts/lint-loop.sh <path-to-SKILL.md>` — Step 4's mechanical structural checks (frontmatter, name/directory match, Training Mode block, retry cap, required sections, at least one done-rule, dual-file output section). Presence/shape only — the judgment calls (are the done-rules actually measurable, does a verification pass resolve) stay in Step 4's prose.

## Assets

- `assets/loop-template.md` — the verbatim Generated Loop Template (the contract). Read it, fill its `<…>` placeholders from the interview, and write the result (everything between its `<!-- BEGIN -->` / `<!-- END -->` markers, excluding the markers) to `<repo-root>/.claude/skills/<loop-name>/SKILL.md`. Keep the Loop Training Mode block byte-faithful.
