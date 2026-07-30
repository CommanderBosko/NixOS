---
name: claude-rules
description: Ensure the current project's CLAUDE.md contains the user's five standing workflow rules — Scope First (Interview), Verification Plan, Parallelize with Sub-Agents, Use Existing Skills First, and Ask via AskUserQuestion — adding any that are missing. Use when the user says "claude-rules", "check claude rules", "apply my rules", "add my rules to this project", or "make sure CLAUDE.md has my rules".
model: haiku
---

# Claude Rules

These five sections are rules the user wants followed in **every** project. This skill checks the current project's `CLAUDE.md` and adds any that are missing, leaving existing ones untouched.

## The five rules (canonical, project-agnostic text)

The exact, canonical Markdown for all five rules lives verbatim in `assets/rules.md`, one `## <Rule Name>` section per rule:

- **Scope First (Interview)**
- **Verification Plan**
- **Parallelize with Sub-Agents**
- **Use Existing Skills First**
- **Ask via AskUserQuestion**

When adding a missing section, **read `assets/rules.md`, find the section whose `## <Rule Name>` header matches the rule you're adding, and insert the exact Markdown block beneath it verbatim.** Do **not** rewrite or "improve" the wording — these are the agreed canonical versions. (If the user's NixOS repo has richer, project-specific variants of these sections, leave those as-is; they already satisfy the rule.)

## Steps

### 1. Locate the project's CLAUDE.md

Find `CLAUDE.md` at the root of the current project (the working directory the session was launched in). Do not touch `~/.claude/CLAUDE.md` or any other project's file — only the current project.

- **If no `CLAUDE.md` exists:** stop and tell the user there is no `CLAUDE.md` in this project. Use the **AskUserQuestion** tool to ask whether to create one containing all five rules, with options **Create** (write a new `CLAUDE.md` with all five canonical rules) and **Skip** (do nothing). Only create it if the user picks Create. Do not create it silently.

### 2. Check which rules are present

Run `scripts/check-rules.sh <path-to-CLAUDE.md>` — it greps for each of the five headings (`## Scope First`, `## Verification Plan`, `## Parallelize with Sub-Agents`, `## Use Existing Skills First`, `## Ask via AskUserQuestion`) and prints `present: <rule>` or `missing: <rule>` per rule. A section counts as present even if its body wording differs from the canonical text above (e.g. a project-specific variant) — the script only matches the heading line.

The script only catches an exact (case-insensitive) heading match. If a rule comes back `missing` but you spot a heading nearby with different wording that might already cover it, that's a judgment call the script can't make: use the **AskUserQuestion** tool — present the ambiguous existing section (its heading and a short excerpt) alongside the rule it might satisfy, with options **Treat as covering it** (leave the section as-is, don't add the canonical block) and **Add the canonical section anyway** (append the canonical block too). Don't guess or duplicate silently.

### 3. Add the missing sections

For each rule that is **missing**, append its canonical Markdown block (read it from the matching `## <Rule Name>` section of `assets/rules.md`). Preserve a blank line between sections. Prefer to keep the five rules grouped together near the top of the file, after any intro paragraph, in this order: Scope First → Verification Plan → Parallelize with Sub-Agents → Use Existing Skills First → Ask via AskUserQuestion. If some already exist mid-file, just append the missing ones near them rather than reordering the whole file.

If all five are already present, report that and make no changes.

### 4. Report

Tell the user exactly which sections were already present and which were added, and the path to the file edited.

## Gotchas

- This skill edits the **current project's** `CLAUDE.md`, which is an ordinary tracked file — not a Claude skill. It does not require a NixOS rebuild to take effect (unlike this skill's own `SKILL.md`, which lives in the NixOS repo and only updates `~/.claude` after a rebuild).
- Never overwrite or reword an existing section. Only append missing ones.
- Don't commit the change unless the user asks — leave it staged for them to review.

- **What went wrong:** the canonical "Verification Plan" block (`assets/rules.md`) says to "state how you'll verify it with the `/verify` skill." Read literally, agents in projects carrying this rule tried to actually invoke it via the Skill tool and got `Skill verify cannot be used with Skill tool due to disable-model-invocation` every time — no `/verify` `SKILL.md` exists anywhere on this machine (project-local or dotfiles-managed) to fix; it's a user-only slash command, not model-invocable. This recurred 3 times in one project's scan window across unrelated tasks (a dispatch-implementation change, a dev-watch session, and a NetscriptDefinitions lookup).
- **How to avoid it:** never call `Skill(verify)` — it will always fail. When the Verification Plan rule is active, fulfill it by stating the verification plan directly in prose up front (which commands/checks you'll run and how you'll confirm each part works), which is what the rule actually asks for; the `/verify` mention describes a user-invocable slash command as a hint for the human, not an instruction to invoke it programmatically. Per the "canonical wording, don't rewrite" rule above, this is documented as a Gotcha rather than a change to `assets/rules.md` — raise it with the user directly if the wording itself should change.

## Assets

- `assets/rules.md` — the five canonical rule blocks (Scope First, Verification Plan, Parallelize with Sub-Agents, Use Existing Skills First, Ask via AskUserQuestion), one per `## <Rule Name>` section. Insert each missing block verbatim from here; never edit the wording.

## Scripts

- `scripts/check-rules.sh <path-to-CLAUDE.md>` — read-only heading-presence check for all five rules (Step 2). Prints `present`/`missing` per rule; does not edit the file.
