---
name: skill-suggestion
description: Analyze the current conversation, identify the most useful repeatable workflow, and build a skill for it. Use when the user says "skill-suggestion", "suggest a skill", "build me a useful skill", "what skill would help here", or "make a skill from this conversation".
---

# Skill Suggestion

Mine the current conversation for a repeatable, multi-step workflow worth saving, propose it, and—on approval—build it as a real skill.

## Steps

### 1. Gather the review window (run this first, no exceptions)

Before looking at anything else — even if the current session is short, empty, or was just `/clear`ed and feels like there's "nothing to scan" — run these two commands. Skipping straight to step 2 because the live conversation looks thin is the exact failure this step exists to prevent: the reuse signal you're after usually lives in *past* sessions, not the current one.

```bash
~/.claude/skills/lib/find-last-skill-invocation.sh skill-suggestion
```

This prints the ISO-8601 timestamp of skill-suggestion's previous invocation for this project, or nothing if it's never run before. Then resolve which transcripts to mine:

```bash
~/.claude/skills/lib/list-transcripts-since.sh "<cutoff-from-above>"
```

Passing an empty string (first-ever run) lists the full transcript history instead. Do not proceed to step 2 until both commands have actually been run and you have the resulting file list in hand.

### 2. Scan for candidates

Review everything done so far this session, **plus** the transcripts listed in step 1. Look for:
- A task performed **two or more times**, or a 4+ step sequence that could be cleanly reused
- Manual workflows the user walked through (commands run, files edited, decisions made in a repeatable order)
- Friction the user hit that a skill could remove

Ignore one-off actions with no reuse value.

The transcript list from step 1 is a stronger reuse signal than "done twice this session" — a workflow repeated across *many* sessions since you last looked is a prime candidate even if it only happened once *this* session. The listed files are large — **never read them whole**; `grep` for recurring command sequences, repeated file-edit patterns, or the same manual steps walked through more than once.

### 3. Rank every viable candidate

Don't collapse to a single pick. List **every** workflow that clears the reuse bar (repeated 2+ times, or a 4+ step reusable sequence), ranked by reuse value. If nothing in the conversation or logs is reusable, say so plainly and stop — do not invent a skill just to have one. A list of one is fine if that's genuinely all that qualifies — don't pad it, and don't artificially trim a longer list down to one.

### 4. Propose them

Present each candidate to the user, concisely, most valuable first:
- **Skill name** (kebab-case) and a one-sentence goal
- **Trigger phrases** (3–5 natural variants)
- **The steps** it would automate, in plain English, citing the concrete commands/paths from this conversation
- **Scope** — recommend global (repo-managed) or project-local based on whether the workflow is NixOS-specific or general

Use the **AskUserQuestion** tool to ask which to proceed with (multi-select if there's more than one candidate), with options **Build it as proposed** (hand off to `new-skill` as-is), **Let me tweak it first** (gather the requested changes, then proceed), and **Skip it** (don't build anything) — applied per candidate the user selects. Don't ask this in free-form prose.

### 5. Build them

For each candidate on **Build it as proposed** (or after applying the user's tweaks), hand off to the `new-skill` skill to draft and write the file, passing the pre-filled goal, triggers, scope, and steps so the user isn't re-interviewed. Skip cleanly over any marked **Skip it**.

### 6. Confirm

Report each skill built: its name, where it was written, the invocation phrases, and (for global/repo-managed skills) the reminder that it must be added to `bosko-claude.nix` and rebuilt before its `~/.claude` symlink appears. For each skill built, suggest running `/ship-skill` next to smoke-test it and carry it through to a commit (and, on confirmation, a push).

## Gotchas

- **`find-last-skill-invocation.sh` misses slash-command invocations.** It only greps for
  assistant-initiated `Skill` tool_use entries — when this skill (or any other) is run the
  normal way, via a user-typed `/skill-suggestion`, Claude Code injects the instructions as
  user-turn content instead, so the detector never records it. `session-closer` hit this for
  real (2026-08-02: reported a stale 2026-07-16 cutoff when two closes had actually happened
  since), and this skill leans on the same detector as its **primary** reuse signal in Step 1
  — a silently-wrong cutoff here directly corrupts the candidate ranking in Step 3. If the
  reported cutoff looks suspiciously old given known recent activity, cross-check
  `git log --oneline | grep 'chore(session):' | head -1` (or any other skill-specific commit
  marker) as a sanity check before trusting it.
