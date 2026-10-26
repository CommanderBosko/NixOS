---
name: skill-suggestion
description: Analyze the current conversation, identify every repeatable workflow worth saving (ranked most useful first), and build a skill for each one approved. Use when the user says "skill-suggestion", "suggest a skill", "build me a useful skill", "what skill would help here", or "make a skill from this conversation".
---

# Skill Suggestion

Mine the current conversation for a repeatable, multi-step workflow worth saving, propose it, and—on approval—build it as a real skill.

## Steps

### 1. Gather the review window (run this first, no exceptions)

Before looking at anything else — even if the current session is short, empty, or was just `/clear`ed and feels like there's "nothing to scan" — run this command. Skipping straight to step 2 because the live conversation looks thin is the exact failure this step exists to prevent: the reuse signal you're after usually lives in *past* sessions, not the current one.

```bash
~/.claude/skills/lib/scope-since-last-run.sh skill-suggestion
```

It prints `cutoff: <ts>` (skill-suggestion's previous invocation for this project, found by `find-last-skill-invocation.sh`), then `transcript-dir: <path>`, then the transcripts to mine, newest first. `cutoff: none` means a first-ever run, and the list is the full transcript history. Do not proceed to step 2 until the command has actually been run and you have the resulting file list in hand.

### 2. Scan for candidates

Review everything done so far this session, **plus** the transcripts listed in step 1. Look for:
- A task performed **two or more times**, or a single sequence whose complexity and reuse potential would clearly pay back the cost of turning it into a skill
- Manual workflows the user walked through (commands run, files edited, decisions made in a repeatable order)
- Friction the user hit that a skill could remove

Ignore one-off actions with no reuse value.

The transcript list from step 1 is a stronger reuse signal than "done twice this session" — a workflow repeated across *many* sessions since you last looked is a prime candidate even if it only happened once *this* session. The listed files are large — **never read them whole**.

With more than ~5 files, fan out instead of grepping them in the main context: split the list into batches of 10–15 and spawn one `transcript-scanner` sub-agent per batch in a single message (`Agent` tool, `subagent_type: "transcript-scanner"`). Tell each to report recurring command sequences, repeated file-edit patterns, and manual steps walked through more than once — what the workflow was and roughly how often, never raw excerpts — and **not** to judge whether a skill for it already exists (step 3 checks that against the real roster). Cap spawns at 20 per message (see `~/.claude/skills/session-analysis/references/concurrency-cap-gotcha.md`); run any further batches in a second wave. With ~5 files or fewer, `grep` them inline for the same patterns.

### 3. Rank and de-duplicate every viable candidate

Don't collapse to a single pick. List **every** workflow that clears the reuse bar (repeated 2+ times, or complex/reusable enough to pay back a skill's setup cost), ranked by reuse value. If nothing in the conversation or logs is reusable, say so plainly and stop — do not invent a skill just to have one. A list of one is fine if that's genuinely all that qualifies — don't pad it, and don't artificially trim a longer list down to one.

Then check each ranked candidate against what already exists. A duplicate of an installed skill, or of one the user already declined, is noise — `pihole-manage-list` once got as far as a draft before anyone noticed `pihole-api` covered it. Per candidate, run (absolute path from this skill's Base directory line — see `~/.claude/skills/lib/script-paths.md`):

```bash
<skill-base-dir>/scripts/candidate-check.sh match <name> "<goal>" "<trigger 1>" "<trigger 2>" ...
```

It prints `STRONG` / `PARTIAL` / `DECLINED` lines (strongest first) or `no-overlap`, and exits 0 either way (including when nothing has ever been declined). Non-zero means a real script error, not "no match":
- **STRONG** — drop the candidate and read the named skill. If the candidate is really a missing edge case in it, hand that to `skill-upgrade` as a Gotcha instead. Mention it in one line ("already covered by X").
- **PARTIAL** — read the named skill. Keep the candidate only if it's a genuinely different workflow; otherwise propose extending that skill rather than a new one.
- **DECLINED** — the candidate matches an entry on the declined list (what that list holds is defined in step 4). The named entry is a candidate the user already said no to, not an installed skill. Drop it and just count it in the step 4 summary. It is never reported as STRONG or PARTIAL.
- **no-overlap** — carry on.

The match is keyword-based: a hit means *go read that skill*, not a verdict, and a miss doesn't prove the roster lacks the workflow — skim the skill list yourself if the candidate feels familiar. If every candidate gets dropped, say so plainly and stop.

### 4. Propose them

Present each candidate to the user, concisely, most valuable first:
- **Skill name** (kebab-case) and a one-sentence goal
- **Trigger phrases** (3–5 natural variants)
- **The steps** it would automate, in plain English, citing the concrete commands/paths from this conversation
- **Scope** — recommend global (repo-managed) or project-local based on whether the workflow is NixOS-specific or general

Use the **AskUserQuestion** tool to ask which to proceed with (multi-select if there's more than one candidate), with options **Build it as proposed** (hand off to `new-skill` as-is), **Let me tweak it first** (gather the requested changes, then proceed), and **Skip it** (don't build anything) — applied per candidate the user selects. Don't ask this in free-form prose.

Right after the answer, record each declined candidate with `<skill-base-dir>/scripts/candidate-check.sh decline <name> "<goal>"`, so later runs stop re-proposing it:
- **Record** a candidate only if it was put to the user in this step and they picked **Skip it** for it, or they didn't select it at all (an unselected candidate counts as skipped).
- **Don't record** a candidate that got **Build it as proposed** or **Let me tweak it first** (a tweak request is a yes to the workflow, even if the tweaked version is later dropped). Don't record one that step 3 already dropped as STRONG, PARTIAL or DECLINED, because the user never saw it. And don't record anything if the question was dismissed without an answer, since no answer is not a decision.
- **What is stored:** one tab-separated line appended to `~/.claude/state/skill-suggestion-declined.tsv`: the date, the project directory name, the candidate name, and the goal you passed. Nothing else is kept, so trigger phrases and steps are not part of the match later. The file is shared across all projects and entries never expire.
- **What a later `match` does with it:** the entry is scored like an installed skill whose name is the stored name and whose description is the stored goal. The same keyword rules as for an installed skill apply: same name, a trigger phrase found in the stored name and goal, or enough shared words. Any hit on it prints as `DECLINED` (see step 3), never as STRONG or PARTIAL. `match` only reads the file and never changes or removes an entry.
- **Reviving a declined candidate:** `candidate-check.sh declined` lists the entries. Delete the entry's line from the file to make it proposable again. There is no `undecline` command.

### 5. Build them

For each candidate on **Build it as proposed** (or after applying the user's tweaks): a single approved candidate hands off directly to the `new-skill` skill, passing the pre-filled goal, triggers, scope, and steps so the user isn't re-interviewed. **Two or more approved candidates in the same pass** spawn one `skill-builder` sub-agent per candidate in parallel (`Agent` tool, `subagent_type: "skill-builder"`) instead of building them one at a time — each spawn gets that candidate's full spec (name, goal, triggers, scope, steps, and a grounding-transcript reference if one exists) so it can build non-interactively with no shared context needed. Skip cleanly over any marked **Skip it**.

### 6. Confirm

Report each skill built: its name, where it was written, the invocation phrases, and (for global/repo-managed skills) the reminder that it must be `git add`ed (no Nix wiring — `claude-hm/files.nix` auto-links it) and rebuilt before its `~/.claude` symlink appears. For each skill built, suggest running `/ship-skill` next to smoke-test it and carry it through to a commit (and, on confirmation, a push).

## Gotchas

Before trusting Step 1's reported cutoff, read `references/gotchas.md` for the
`find-last-skill-invocation.sh` slash-command history and the right marker to cross-check it against.
