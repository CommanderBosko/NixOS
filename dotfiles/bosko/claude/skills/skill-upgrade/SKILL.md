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
`## Gotchas` section at the end of the file. Present the proposed edit to the user and confirm
via the **AskUserQuestion tool** (options **Apply** / **Skip**) before writing — a low-stakes,
easily-reversible append, but a clean pick beats inferring approval from a free-form reply.

### 5. Verify and report

After editing repo-managed skills, run the `nixos-dry-run` skill to confirm the config still
evaluates. Report which skills were upgraded, the gotcha added to each, and the reminder that a
rebuild + reboot (it only stages the change for next boot) + new session is needed before the
change reaches `~/.claude`.

## Gotchas

- **`nixos-dry-run` is project-local to `~/NixOS`, not a global skill** — invoking it via the
  Skill tool from a different project's working directory fails with
  `Unknown skill: nixos-dry-run` (observed from a FinanceGuru session). When step 5 runs from
  outside `~/NixOS`, verify with the direct command instead:
  `nh os boot /home/bosko/NixOS --dry`.
- **`find-last-skill-invocation.sh` misses slash-command invocations.** It only greps for
  assistant-initiated `Skill` tool_use entries — when this skill (or the skill being fed to
  `find-skill-misfires.sh`'s `since-timestamp` arg in Step 1) is run the normal way, via a
  user-typed `/skill-upgrade`, Claude Code injects the instructions as user-turn content
  instead, so the detector never records it. `session-closer` already paid for this discovery
  for real (2026-08-02: reported a stale cutoff after two runs had actually happened since) —
  worth a mild irony flag, since fixing exactly this kind of undocumented gotcha in *other*
  skills is this skill's entire job. Cross-check a skill-specific commit marker in `git log`
  if the reported cutoff looks suspiciously old before trusting the misfire scan's scope.
