---
name: skill-upgrade
description: Review skills used in this conversation, identify mistakes or friction they caused, and add a Gotchas section to each so the same mistake isn't repeated. Use when the user says "skill-upgrade", "upgrade a skill", "add a gotcha", "harden the skill", or "fix the skill so we don't make that mistake again".
---

# Skill Upgrade

Find skills that misfired this session and amend them with a **Gotchas** section capturing what went wrong and how to avoid it.

## Steps

### 1. Identify candidate skills

Scan the conversation for every skill that was invoked. Flag the ones where something went wrong or was clumsy:
- A step failed, produced a wrong path, or had to be redone
- The user corrected the workflow mid-run
- A repo-specific constraint (e.g. repo-managed skills, dry-run-before-commit) was missed
- Anything that would trip up the next run the same way

If no skill caused friction this session, say so plainly and stop.

### 2. Locate the source file

For each flagged skill, find its source `SKILL.md`. Repo-managed global skills live under
`dotfiles/bosko/claude/skills/<name>/SKILL.md` — **always edit the repo copy**, never the
read-only `~/.claude/skills/` symlink. Project-local skills live under `.claude/skills/<name>/SKILL.md`.

### 3. Draft the Gotcha

For each skill, write a concise entry stating:
- **What went wrong** (the concrete mistake, grounded in this conversation)
- **How to avoid it** (the rule or check to apply next time)

Keep each gotcha to one or two sentences. Don't pad with hypotheticals — only real, observed problems.

### 4. Amend the skill

If the skill already has a `## Gotchas` section, append the new entry. Otherwise add a
`## Gotchas` section at the end of the file. Present the proposed edit to the user before writing.

### 5. Verify and report

After editing repo-managed skills, run the `nixos-dry-run` skill to confirm the config still
evaluates. Report which skills were upgraded, the gotcha added to each, and the reminder that a
rebuild + new session is needed before the change reaches `~/.claude`.
