---
name: skill-suggestion
description: Analyze the current conversation, identify the most useful repeatable workflow, and build a skill for it. Use when the user says "skill-suggestion", "suggest a skill", "build me a useful skill", "what skill would help here", or "make a skill from this conversation".
---

# Skill Suggestion

Mine the current conversation for a repeatable, multi-step workflow worth saving, propose it, and—on approval—build it as a real skill.

## Steps

### 1. Scan the conversation

Review everything done so far this session. Look for:
- A task performed **two or more times**, or a 4+ step sequence that could be cleanly reused
- Manual workflows the user walked through (commands run, files edited, decisions made in a repeatable order)
- Friction the user hit that a skill could remove

Ignore one-off actions with no reuse value.

**Mine past sessions too.** The strongest reuse signal isn't "done twice this session" — it's a workflow you repeat across *many* sessions. Resolve the current project's transcript directory with the shared helper (also used by `skill-upgrade`/`session-closer` — don't re-derive the cwd-to-slug logic by hand):

```bash
~/.claude/skills/lib/find-transcript-dir.sh
```

It prints the directory (e.g. this repo → `~/.claude/projects/-home-bosko-NixOS/`) holding the project's `*.jsonl` transcripts. They are large — **never read them whole**; `grep` for recurring command sequences, repeated file-edit patterns, or the same manual steps walked through in multiple sessions. A workflow that shows up across several transcripts is a prime candidate even if it only happened once *this* session.

### 2. Pick the single best candidate

Choose the one workflow with the highest reuse value. If nothing in the conversation is reusable, say so plainly and stop — do not invent a skill just to have one.

### 3. Propose it

Present to the user, concisely:
- **Skill name** (kebab-case) and a one-sentence goal
- **Trigger phrases** (3–5 natural variants)
- **The steps** it would automate, in plain English, citing the concrete commands/paths from this conversation
- **Scope** — recommend global (repo-managed) or project-local based on whether the workflow is NixOS-specific or general

Use the **AskUserQuestion** tool to ask whether to proceed, with options **Build it as proposed** (hand off to `new-skill` as-is), **Let me tweak it first** (gather the requested changes, then proceed), and **Skip it** (don't build anything). Don't ask this in free-form prose.

### 4. Build it

On **Build it as proposed** (or after applying the user's tweaks), hand off to the `new-skill` skill to draft and write the file, passing the pre-filled goal, triggers, scope, and steps so the user isn't re-interviewed. On **Skip it**, stop cleanly.

### 5. Confirm

Report the skill name, where it was written, the invocation phrases, and (for global/repo-managed skills) the reminder that it must be added to `bosko-claude.nix` and rebuilt before its `~/.claude` symlink appears.
