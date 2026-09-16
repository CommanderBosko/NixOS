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

**Always check the logs since the last time skill-upgrade itself ran** — not just this session. First get the cutoff:

```bash
~/.claude/skills/lib/find-last-skill-invocation.sh skill-upgrade
```

This prints the ISO-8601 timestamp of skill-upgrade's previous invocation for this project, or nothing if it's never run before. Then feed that cutoff into the misfire scan:

```bash
scripts/find-skill-misfires.sh <repo-root> [max-files] [since-timestamp]
```

from this skill's own base directory (the "Base directory for this skill" line shown when it launched — e.g. `~/.claude/skills/skill-upgrade/scripts/find-skill-misfires.sh`). Pass the cutoff as the third argument and it scans every transcript touched since then instead of a fixed recent-N window; omit it (or leave it empty) to fall back to the most-recently-modified `max-files` transcripts (default 15) — that fallback only applies on skill-upgrade's first-ever run for this project. It prints every `is_error` tool result alongside the tool call and the `Skill` that was active at the time. Treat a recurring cross-session failure — the same skill, same tool, same error shape — as a stronger signal than a one-off slip this session.

**Report every misfire found, not just one.** List each flagged skill and its gotcha in Step 3/4 below — don't stop at the first candidate. A single finding is fine if that's genuinely all the logs turned up, but don't truncate a longer list for brevity.

### 2. Locate the source file

For each flagged skill, find its source `SKILL.md`. **Check `.claude/skills/<name>/SKILL.md` in
the current project first** — repo/project-specific skills (scaffolding, RAM audits, and other
tooling tied to one codebase) usually live there *only*, with no global copy at all. Don't assume
global by default and go straight to `~/.claude/skills/<name>/SKILL.md`; that read fails outright
for a project-local-only skill. Only once a project-local copy is ruled out, treat it as
repo-managed global, living under `dotfiles/bosko/claude/skills/<name>/SKILL.md` — **always edit
that repo copy**, never the read-only `~/.claude/skills/` symlink.

### 3. Draft the Gotcha

For each skill, write a concise entry stating:
- **What went wrong** (the concrete mistake, grounded in this conversation)
- **How to avoid it** (the rule or check to apply next time)

Keep each gotcha to one or two sentences. Don't pad with hypotheticals — only real, observed problems.

### 4. Amend the skill

If the target skill already has a `references/gotchas.md` — or its inline `## Gotchas` section already runs past two or three short bullets — append the new entry to `references/gotchas.md` instead (create it if it doesn't exist yet, with a one-line topic header, and make sure SKILL.md's `## Gotchas` section carries an accurate one-line pointer to it). This keeps heavy, narrow-case Gotchas content out of SKILL.md's always-loaded body, per this repo's skill-lightening convention.

Otherwise (a skill with no gotchas yet, or only one or two short ones) append directly to its inline `## Gotchas` section — don't create a reference file just for a single short entry. If the skill has no `## Gotchas` section at all, add one at the end of the file.

Either way, this is a purely additive, reversible edit to a file you're already trusted to maintain — auto-apply it directly (matches how `improve-system` classifies this same edit when it orchestrates this skill) and report what was added, and where (inline vs. `references/gotchas.md`), in Step 5, rather than pausing for a per-skill confirm.

### 5. Verify and report

After editing repo-managed skills, run the `nixos-dry-run` skill to confirm the config still
evaluates. Report which skills were upgraded, the gotcha added to each, and the reminder that a
rebuild + reboot (it only stages the change for next boot) is needed before the change reaches
`~/.claude` — no new session required beyond that, since skill discovery reads from disk
per-invocation.

## Gotchas

See `references/gotchas.md` for past misfires before trusting a misfire scan's completeness.
