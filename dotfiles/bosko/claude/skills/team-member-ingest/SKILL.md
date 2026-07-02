---
name: team-member-ingest
description: Ingest pasted content (transcripts, articles, posts, notes) as training data for a named person and save each piece raw under the shared knowledge base. Use when the user says "team-member-ingest", "ingest this for [person]", "add training data for [person]", "feed this to [person]'s profile", or "learn [person] from this". (Building the profile from the saved raw is a separate step — /team-member-synthesize.)
---

# Team Member Ingest

Ingest content the user pastes — transcripts, articles, posts, notes, whatever — as training data for a specific person (usually an advisor from their `team-meeting` board), and save each piece raw under the shared knowledge base. This skill does **one job: store the raw source**. Distilling those raw files into a profile is a separate skill, `/team-member-synthesize`, run after ingest. All data lives in the shared knowledge base in the Nix repo at:

```
/home/bosko/NixOS/dotfiles/bosko/claude/knowledge/
```

so it's version-controlled and available from any project. (Note: `knowledge/raw/` is gitignored — raw source stays local; synthesized profiles are committed.) This path is shared verbatim across `team-meeting`, `team-member-ingest`, `team-member-synthesize`, and `new-team-member` — if it ever moves, update all four.

(Bucket: Utility — save each pasted piece raw, verbatim, every time.)

## Arguments

Parse from the user's request:

- **`<person>`** (required) — the advisor/person the pasted content trains, e.g. *"ingest this for Alex Hormozi"*. This name becomes the `person-slug` (lowercase, spaces → hyphens, punctuation dropped) the raw files are filed under at `knowledge/raw/<person-slug>/`. If it's not in the invocation phrase, ask whose training data this is before saving anything.

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

### 3. Report and hand off to synthesis

Tell the user: who you ingested for, how many raw pieces you saved, and the exact paths under `knowledge/raw/<person-slug>/`. Mention that raw files are local-only (gitignored).

Then suggest the next step — this skill deliberately does **not** rebuild the profile itself:

> Saved N raw piece(s) for **<Person Name>**. Run `/team-member-synthesize <Person Name>` to fold this into their profile.

Do not run synthesis automatically.

## Rules

- Save raw content **verbatim** — don't paraphrase or trim the source; the raw files are the ground truth.
- Never overwrite raw files; disambiguate collisions with a numeric suffix.
- One person per run. If the user pastes material for multiple people, ask them to run the skill once per person.
- This skill only writes under `knowledge/raw/<person-slug>/`. It never touches `knowledge/<person-slug>/team-member.md` — that is `/team-member-synthesize`'s job.
