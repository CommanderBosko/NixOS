---
name: team-member-synthesize
description: Distill all raw training data saved for a named person into a synthesized profile of their core ideas, vocabulary, stances, and recurring stories. Use when the user says "team-member-synthesize", "synthesize [person]", "rebuild [person]'s profile", "refresh [person]'s profile", or "build the profile for [person]".
---

# Team Member Synthesize

Read **all** raw training data on file for a person and distill it into a durable profile of how that person thinks. This is the synthesis half of the team-member pipeline: `/team-member-ingest` saves raw source; this skill turns the accumulated raw into a profile. It stands alone — run it any time, with or without a fresh ingest, to rebuild or refine a profile from everything currently on file.

(Bucket: Data Enrichment is *not* it — there is no external fetch; this is local synthesis. Treat it as a standalone build step over saved raw data.)

Knowledge base in the Nix repo — read the canonical base path from
`~/.claude/skills/_shared/knowledge-base-path.md` (the single source of truth shared by
`team-meeting`, `team-member-ingest`, `team-member-synthesize`, and `new-team-member` — if
the knowledge base ever moves, update only that one file).

`knowledge/raw/<person-slug>/` holds the raw source (gitignored, local-only); `knowledge/<person-slug>/team-member.md` is the synthesized profile (committed).

## Arguments

Parse from the user's request:

- **`<person>`** (required) — the advisor/person whose raw corpus to distill, e.g. *"synthesize Alex Hormozi"*. This name becomes the `person-slug` (lowercase, spaces → hyphens, punctuation dropped) whose raw files at `knowledge/raw/<person-slug>/` are read and folded into `knowledge/<person-slug>/team-member.md`. If it's not in the invocation phrase, ask whose profile to build before proceeding.

## Steps

### 1. Identify the person

- Determine **whose** profile to synthesize. If the name wasn't given in the invocation, ask for it.
- Derive the `person-slug`: lowercase, spaces → hyphens, drop punctuation (e.g. "Alex Hormozi" → `alex-hormozi`).
- Confirm raw data exists:

```bash
ls "$(cat ~/.claude/skills/_shared/knowledge-base-path.md)raw/<person-slug>/"
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

Read the frontmatter/structure template from `assets/profile-template.md` (relative to this
skill's directory) and fill its placeholders from the distilled raw corpus.

If `knowledge/<person-slug>/team-member.md` already exists, **merge** — extend and refine rather than overwriting; don't lose prior synthesis. Refresh the "Sources ingested" list to match what's currently under `raw/<person-slug>/`.

### 4. Report

Tell the user whose profile you (re)built, how many raw sources fed it, and a 2–3 sentence summary of what the synthesis captures or what changed since last time. Note that the profile is committed while the raw sources stay local-only.

## Rules

- Synthesis is your own distillation across **all** sources — be specific and quote signature phrasing where illuminating, but don't fabricate ideas the person didn't express.
- Always re-read the full raw corpus; never synthesize from a single file.
- Never clobber an existing profile — merge into it.
- One person per run.

## Assets

- `assets/profile-template.md` — the frontmatter + section skeleton for the synthesized profile. Read and fill it; never inline the template in prose.
