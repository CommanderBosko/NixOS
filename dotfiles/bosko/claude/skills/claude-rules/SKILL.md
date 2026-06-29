---
name: claude-rules
description: Ensure the current project's CLAUDE.md contains the user's four standing workflow rules — Scope First (Interview), Verification Plan, Parallelize with Sub-Agents, and Use Existing Skills First — adding any that are missing. Use when the user says "claude-rules", "check claude rules", "apply my rules", "add my rules to this project", or "make sure CLAUDE.md has my rules".
---

# Claude Rules

These four sections are rules the user wants followed in **every** project. This skill checks the current project's `CLAUDE.md` and adds any that are missing, leaving existing ones untouched.

## The four rules (canonical, project-agnostic text)

The exact, canonical Markdown for all four rules lives verbatim in `assets/rules.md`, one `## <Rule Name>` section per rule:

- **Scope First (Interview)**
- **Verification Plan**
- **Parallelize with Sub-Agents**
- **Use Existing Skills First**

When adding a missing section, **read `assets/rules.md`, find the section whose `## <Rule Name>` header matches the rule you're adding, and insert the exact Markdown block beneath it verbatim.** Do **not** rewrite or "improve" the wording — these are the agreed canonical versions. (If the user's NixOS repo has richer, project-specific variants of these sections, leave those as-is; they already satisfy the rule.)

## Steps

### 1. Locate the project's CLAUDE.md

Find `CLAUDE.md` at the root of the current project (the working directory the session was launched in). Do not touch `~/.claude/CLAUDE.md` or any other project's file — only the current project.

- **If no `CLAUDE.md` exists:** stop and tell the user there is no `CLAUDE.md` in this project. Ask whether to create one containing all four rules. Only create it if they say yes. Do not create it silently.

### 2. Check which rules are present

Read the file and check for each of the four sections by heading. Match on the heading text (`## Scope First`, `## Verification Plan`, `## Parallelize with Sub-Agents`, `## Use Existing Skills First`) — a section counts as present even if its body wording differs from the canonical text above (e.g. a project-specific variant). Treat case-insensitively and tolerate minor heading wording differences; when unsure whether an existing section covers a rule, ask the user rather than duplicating it.

### 3. Add the missing sections

For each rule that is **missing**, append its canonical Markdown block (read it from the matching `## <Rule Name>` section of `assets/rules.md`). Preserve a blank line between sections. Prefer to keep the four rules grouped together near the top of the file, after any intro paragraph, in this order: Scope First → Verification Plan → Parallelize with Sub-Agents → Use Existing Skills First. If some already exist mid-file, just append the missing ones near them rather than reordering the whole file.

If all four are already present, report that and make no changes.

### 4. Report

Tell the user exactly which sections were already present and which were added, and the path to the file edited.

## Gotchas

- This skill edits the **current project's** `CLAUDE.md`, which is an ordinary tracked file — not a Claude skill. It does not require a NixOS rebuild to take effect (unlike this skill's own `SKILL.md`, which lives in the NixOS repo and only updates `~/.claude` after a rebuild).
- Never overwrite or reword an existing section. Only append missing ones.
- Don't commit the change unless the user asks — leave it staged for them to review.

## Assets

- `assets/rules.md` — the four canonical rule blocks (Scope First, Verification Plan, Parallelize with Sub-Agents, Use Existing Skills First), one per `## <Rule Name>` section. Insert each missing block verbatim from here; never edit the wording.
