---
name: team-member-synthesize
description: Distill all raw training data saved for a named person into a synthesized profile of their core ideas, vocabulary, stances, and recurring stories. Use when the user says "team-member-synthesize", "synthesize [person]", "rebuild [person]'s profile", "refresh [person]'s profile", or "build the profile for [person]".
---

# Team Member Synthesize

Read **all** raw training data on file for a person and distill it into a durable profile of how that person thinks. This is the synthesis half of the team-member pipeline: `/team-member-ingest` saves raw source; this skill turns the accumulated raw into a profile. It stands alone — run it any time, with or without a fresh ingest, to rebuild or refine a profile from everything currently on file.

(Bucket: Data Enrichment is *not* it — there is no external fetch; this is local synthesis. Treat it as a standalone build step over saved raw data.)

Knowledge base in the Nix repo:

```
/home/bosko/NixOS/dotfiles/bosko/claude/knowledge/
```

`knowledge/raw/<person-slug>/` holds the raw source (gitignored, local-only); `knowledge/<person-slug>/team-member.md` is the synthesized profile (committed).

## Steps

### 1. Identify the person

- Determine **whose** profile to synthesize. If the name wasn't given in the invocation, ask for it.
- Derive the `person-slug`: lowercase, spaces → hyphens, drop punctuation (e.g. "Alex Hormozi" → `alex-hormozi`).
- Confirm raw data exists:

```bash
ls /home/bosko/NixOS/dotfiles/bosko/claude/knowledge/raw/<person-slug>/
```

If the directory is missing or empty, tell the user there's nothing to synthesize and point them at `/team-member-ingest` to add raw source first. Stop.

### 2. Read all raw files

Read **every** file under `knowledge/raw/<person-slug>/` — not just the most recent. The profile is a distillation across the person's entire corpus, so a re-synthesis always reconsiders everything on file.

### 3. Write (or merge into) the profile

Distill the raw into `knowledge/<person-slug>/team-member.md`. Create the directory if needed. Cover, at minimum:

- **Core ideas** — the central frameworks, theses, and mental models they return to.
- **Vocabulary** — signature terms, phrases, and coinages they use, with what each means to them.
- **Stances** — strong positions, what they're for and against, and any notable contrarian takes.
- **Recurring stories** — anecdotes, case studies, and examples they tell repeatedly.

Use this structure:

```
---
name: <person-slug>
description: Synthesized profile of <Person Name> — core ideas, vocabulary, stances, recurring stories. Use to channel their thinking when advising the user.
metadata:
  type: reference
---

# <Person Name>

**One-line identity:** …

## Core ideas
- …

## Vocabulary
- **<term>** — …

## Stances
- …

## Recurring stories
- …

## Sources ingested
- <list of the raw files under raw/<person-slug>/>
```

If `knowledge/<person-slug>/team-member.md` already exists, **merge** — extend and refine rather than overwriting; don't lose prior synthesis. Refresh the "Sources ingested" list to match what's currently under `raw/<person-slug>/`.

### 4. Report

Tell the user whose profile you (re)built, how many raw sources fed it, and a 2–3 sentence summary of what the synthesis captures or what changed since last time. Note that the profile is committed while the raw sources stay local-only.

## Rules

- Synthesis is your own distillation across **all** sources — be specific and quote signature phrasing where illuminating, but don't fabricate ideas the person didn't express.
- Always re-read the full raw corpus; never synthesize from a single file.
- Never clobber an existing profile — merge into it.
- One person per run.
