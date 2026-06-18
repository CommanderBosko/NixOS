---
name: claude-rules
description: Ensure the current project's CLAUDE.md contains the user's four standing workflow rules — Scope First (Interview), Verification Plan, Parallelize with Sub-Agents, and Use Existing Skills First — adding any that are missing. Use when the user says "claude-rules", "check claude rules", "apply my rules", "add my rules to this project", or "make sure CLAUDE.md has my rules".
---

# Claude Rules

These four sections are rules the user wants followed in **every** project. This skill checks the current project's `CLAUDE.md` and adds any that are missing, leaving existing ones untouched.

## The four rules (canonical, project-agnostic text)

When adding a missing section, insert the exact Markdown below. Do **not** rewrite or "improve" the wording — these are the agreed canonical versions. (If the user's NixOS repo has richer, project-specific variants of these sections, leave those as-is; they already satisfy the rule.)

### Scope First (Interview)

```markdown
## Scope First (Interview)

Before you do any work, use the `/interview` skill to pin down the real goal with the user — don't start building from a fuzzy or assumed understanding of the request. Surface the unknowns, confirm scope and constraints, and only proceed once the target is clear. Do this in tandem with the Verification Plan below: the interview establishes *what* we're building and how we'll know it's done, and the verification plan establishes *how we'll prove* it works. Lay out both together, up front, before starting the work.
```

### Verification Plan

```markdown
## Verification Plan

Before you do any work, state how you'll verify it with the `/verify` skill — say up front how you'll confirm each part actually works before calling it done. Pick the checks that fit this project (build, test suite, linter, type-check, running the app, hitting the endpoint, reading the logs) and name the specific commands. Lay out the plan with the work, not after it.
```

### Parallelize with Sub-Agents

```markdown
## Parallelize with Sub-Agents

**This rule is your standing authorization to spawn sub-agents — you do not need to ask first.** Once scope and the verification plan are set, before starting any task with more than one independent part, stop and run a parallelization check. This is a required step, not an aspiration: ask "Can I split this into pieces that don't depend on each other's output?" If yes, spawn one sub-agent per piece in a single message and let them run concurrently.

Trigger parallelization whenever you hit any of these:
- About to research, search, or read across 2+ areas of the tree that don't depend on each other.
- About to scaffold or draft 2+ files whose *contents* don't reference each other.
- You catch yourself planning "do A, then B, then C" where B doesn't need A's result.

Reserve serial work for genuine dependencies — e.g. a new file and the line elsewhere that imports it are coupled, so keep them together. When the pieces are independent, default to fanning out breadth-first; state in your plan which pieces run in parallel and why.
```

### Use Existing Skills First

```markdown
## Use Existing Skills First

Before doing a task by hand, check whether an existing skill already covers it and invoke it instead of improvising. Skills encode the agreed, repeatable way to do a thing — prefer them over ad-hoc steps. If you find yourself doing the same multi-step task a second time and no skill exists, offer to create one.
```

## Steps

### 1. Locate the project's CLAUDE.md

Find `CLAUDE.md` at the root of the current project (the working directory the session was launched in). Do not touch `~/.claude/CLAUDE.md` or any other project's file — only the current project.

- **If no `CLAUDE.md` exists:** stop and tell the user there is no `CLAUDE.md` in this project. Ask whether to create one containing all four rules. Only create it if they say yes. Do not create it silently.

### 2. Check which rules are present

Read the file and check for each of the four sections by heading. Match on the heading text (`## Scope First`, `## Verification Plan`, `## Parallelize with Sub-Agents`, `## Use Existing Skills First`) — a section counts as present even if its body wording differs from the canonical text above (e.g. a project-specific variant). Treat case-insensitively and tolerate minor heading wording differences; when unsure whether an existing section covers a rule, ask the user rather than duplicating it.

### 3. Add the missing sections

For each rule that is **missing**, append its canonical Markdown block (from above). Preserve a blank line between sections. Prefer to keep the four rules grouped together near the top of the file, after any intro paragraph, in this order: Scope First → Verification Plan → Parallelize with Sub-Agents → Use Existing Skills First. If some already exist mid-file, just append the missing ones near them rather than reordering the whole file.

If all four are already present, report that and make no changes.

### 4. Report

Tell the user exactly which sections were already present and which were added, and the path to the file edited.

## Gotchas

- This skill edits the **current project's** `CLAUDE.md`, which is an ordinary tracked file — not a Claude skill. It does not require a NixOS rebuild to take effect (unlike this skill's own `SKILL.md`, which lives in the NixOS repo and only updates `~/.claude` after a rebuild).
- Never overwrite or reword an existing section. Only append missing ones.
- Don't commit the change unless the user asks — leave it staged for them to review.
