---
name: team-member-ingest
description: Ingest pasted content (transcripts, articles, posts, notes) as training data for a named person, save each piece raw under the shared knowledge base, then synthesize a profile of that person's core ideas, vocabulary, stances, and recurring stories. Use when the user says "team-member-ingest", "ingest this for [person]", "add training data for [person]", "feed this to [person]'s profile", or "learn [person] from this".
---

# Team Member Ingest

Ingest content the user pastes — transcripts, articles, posts, notes, whatever — as training data for a specific person (usually an advisor from their `team-meeting` board). Save each piece raw, then synthesize a durable profile of how that person thinks. All data lives in the shared knowledge base in the Nix repo at:

```
/home/bosko/NixOS/dotfiles/bosko/claude/knowledge/
```

so it's version-controlled and available from any project. (Note: `knowledge/raw/` is gitignored — raw source stays local; synthesized profiles are committed.)

## Steps

### 1. Identify the person and get the content

- Determine **whose** training data this is. If the person's name wasn't given in the invocation, ask for it.
- Derive a `person-slug`: lowercase, spaces → hyphens, drop punctuation (e.g. "Alex Hormozi" → `alex-hormozi`).
- If the user hasn't already pasted the content, prompt them: **"Paste the content you want me to ingest for [PERSON NAME] — transcripts, articles, posts, notes, anything. Send it all; I'll split it into pieces."** Wait for it.

### 2. Save each piece raw

For **each distinct piece** in what they pasted (split on obvious boundaries — separate articles, separate transcripts, etc.):

- Write it verbatim to `knowledge/raw/<person-slug>/<YYYY-MM-DD>-<short-title-slug>.md`, using **today's date** and a short slug derived from the piece's title or topic. Create the directory if needed; never overwrite an existing raw file — disambiguate with a numeric suffix.
- Prepend a small header so the source is traceable, then the raw text unchanged:

```
---
person: <Person Name>
type: <transcript | article | post | note>
source: <url or where it came from, if known>
ingested: <YYYY-MM-DD>
---

<the pasted content, verbatim>
```

### 3. Synthesize the person's profile

Read **all** raw files for this person (the new ones plus any already under `knowledge/raw/<person-slug>/`) and distill them into `knowledge/<person-slug>/team-member.md`. Create the directory if needed. Cover, at minimum:

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

If `knowledge/<person-slug>/team-member.md` already exists, **merge** the new material into it — extend and refine rather than overwriting; don't lose prior synthesis. Update the "Sources ingested" list.

### 4. Report

Tell the user: who you ingested for, how many raw pieces you saved and where, and a 2–3 sentence summary of what the new material added or changed in the synthesized profile. Mention that raw files are local-only (gitignored) while the profile is committed.

## Rules

- Save raw content **verbatim** — don't paraphrase or trim the source; the raw files are the ground truth.
- Synthesis is your own distillation across all sources — be specific and quote signature phrasing where it's illuminating, but don't fabricate ideas the person didn't express.
- One person per run. If the user pastes material for multiple people, ask them to run the skill once per person.
- Never overwrite raw files; always merge (never clobber) the synthesized profile.
