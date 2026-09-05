---
name: improve-memory
description: Reconcile session-analysis's mined candidates with every project's existing memory files and real CLAUDE.md files -- merge duplicates, fix stale dates and dead links automatically, and propose (never auto-apply) CLAUDE.md restructuring or contradiction fixes. Writes a Memory Improvement Overview to ~/.claude/dream/ for human review. Use when the user says "/improve-memory", "reconcile my memory files", "clean up memory duplicates", or when the `dream` skill invokes it after session-analysis.
---

# Improve Memory

Takes `session-analysis`'s mined candidates and reconciles them against **every**
project's real state: its memory files (`~/.claude/projects/<slug>/memory/*.md` +
`MEMORY.md`) and its real CLAUDE.md files (root + any subdirectory ones already in the
tree, plus the global `~/.claude/CLAUDE.md` once). Produces one **Memory Improvement
Overview** file per run, split into changes already made (auto-apply tier) and changes
proposed but waiting on human sign-off (flag tier).

## Arguments

Invocation shape: `[analysis-file-path]`.

- **`[analysis-file-path]`** (optional) — path to a `session-analysis` output file
  (`~/.claude/dream/analysis-*.md`). If omitted, use the most recent
  `~/.claude/dream/analysis-*.md` by filename (the timestamp sorts lexicographically).
  If none exist at all, say so and stop — there's nothing to reconcile yet.

## Mapping a project dir back to its real path

Same cross-project problem `session-analysis` solves: use
`~/.claude/skills/lib/list-all-projects.sh` to get `<real-path>\t<transcript-dir>` pairs.
**Never** un-slugify a `~/.claude/projects/<slug>` directory name by replacing `-` with
`/` — a real path segment containing a literal hyphen (e.g.
`/home/bosko/projects/Codingame-Mad-Pod-Racing`) makes that unreliable. A project whose
real path comes back `UNKNOWN` (no `.jsonl` transcripts left to read a `cwd` from) still
gets its memory dir processed — it just can't be cross-checked against real CLAUDE.md
files, since there's no real path to look under. Say so explicitly in that project's
"Project Coverage" line rather than silently skipping it.

## Step 1 — Read the analysis file

Read the given (or most recent) `analysis-*.md`. It lists candidate memory-worthy items
per project, already tagged `fact` / `decision` / `correction` / `gotcha`.

## Step 2 — Gather each project's real state

For every project in the analysis file's project list (via `list-all-projects.sh`):

1. **Memory files**: `ls <transcript-dir>/memory/` and read `MEMORY.md`'s index plus any
   memory files whose topic could relate to this pass's candidates (the ones the analysis
   file flagged, or ones its own dead-link/dedup pass touches — see Step 3).
2. **Dead links / stale index entries** (deterministic, run per project):
   ```bash
   ~/.claude/skills/improve-memory/scripts/find-memory-issues.sh <transcript-dir>/memory
   ```
   Only `DEAD_INDEX_LINK` and `WIKILINK_NEAR_MISS` findings are real staleness —
   `WIKILINK_UNRESOLVED` is very often an **intentional** forward-reference
   (`save-memory`'s own convention: "a link whose target doesn't exist yet is fine; it
   marks something worth writing later"). Never auto-fix or even flag an `UNRESOLVED`
   finding as broken — it isn't one.
3. **Real CLAUDE.md files** (skip if real path is `UNKNOWN`):
   ```bash
   ~/.claude/skills/improve-memory/scripts/find-claude-md-files.sh <real-project-path>
   ```
   Read each returned file. Also read the global `~/.claude/CLAUDE.md` once per run (not
   per project — it's shared).

## Step 3 — Decide what's auto-apply vs. flag tier

This boundary is the whole point of the skill — get it right, don't blur it.

### Auto-apply tier (do it now, no approval needed)

- **Exact/near-duplicate memory merges** — two memory files (or a new analysis candidate
  and an existing file) describing the *same fact* with no conflicting information. Keep
  the more complete/accurate file, fold in anything the other adds, update `MEMORY.md`'s
  index (remove the redundant line), delete the redundant file. This is what
  `save-memory`'s own Step 2 ("update that file instead of creating a duplicate") already
  does for a single new fact — this just runs the same judgment against the whole corpus.
- **Stale-date fixes** — a memory body still carries an unconverted relative date
  ("today", "next week") that `save-memory`'s own Step 1 should have converted to
  absolute `YYYY-MM-DD`, or a date that's objectively wrong given the file's own later
  content (e.g. a "PENDING" note whose own linked memory shows it was already resolved
  weeks ago).
- **Dead-file/link cleanup** — `DEAD_INDEX_LINK` findings (remove or fix the stale
  `MEMORY.md` line) and `WIKILINK_NEAR_MISS` findings (fix the `[[slug]]` text to the
  real filename). Never touch a `WIKILINK_UNRESOLVED` finding — see Step 2.2.

### Flag tier (never auto-applied — needs `Status: APPROVED`)

- **Any CLAUDE.md edit or restructuring** — including creating a new subdirectory
  `CLAUDE.md` and moving content into it. When a large/monolithic CLAUDE.md has a section
  that only applies to one part of a project (e.g. a gaming-host-only hardware section in
  a NixOS-wide root CLAUDE.md), propose moving it into a **literal `CLAUDE.md`** placed in
  that subfolder — not a custom name like `RULES.md`, which would never auto-load. Leave
  the root CLAUDE.md a pointer/summary line if useful. Write out the **exact** proposed
  subdirectory file content in the overview (see the template) so applying it later is
  copy-paste, not re-derivation.
- **Resolving a real contradiction between two memories** — two memories that assert
  *different facts* about the same thing (not just differently-worded duplicates of the
  same fact — that's auto-apply territory above). State both versions, which one looks
  authoritative and why (e.g. more recent, more specific, corroborated by git history),
  and the exact resulting edit.
- **Any outright deletion** of a memory file (as opposed to a content-preserving merge
  where the surviving file keeps everything of value).

When genuinely unsure which tier something belongs in, flag it — the cost of an extra
review item is far lower than the cost of an unreviewed CLAUDE.md edit or a silently
deleted memory.

## Step 4 — Apply the auto-apply tier now

Make the edits directly (Edit/Write the memory files and `MEMORY.md` indexes involved).
Do this before writing the overview file, so its "Auto-Applied Changes" section reports
what already happened, past tense.

## Step 5 — Write the Memory Improvement Overview

Read `assets/overview-template.md` and fill it in:
`~/.claude/dream/overview-<ISO8601>.md` (same timestamp format as `session-analysis`:
`date -u +%Y%m%dT%H%M%SZ`).

- **`Status: PENDING_REVIEW`** — keep this line's exact shape; see the template's own
  contract comment. This is what `dream` parses.
- **Auto-Applied Changes** — one line per Step 4 edit, past tense, specific (which files,
  what changed).
- **Flagged for Review** — one numbered item (`### F1`, `F2`, ...) per Step 3 flag-tier
  finding: a `**Why:**` line and a `**Proposed change:**` with exact, literal content —
  never "restructure this section," always the actual new file content / actual resulting
  text.
- **Project Coverage** — one line per project considered, even ones with nothing to
  report, and explicitly note `UNKNOWN` real-path projects as "memory-only pass, real path
  unknown, CLAUDE.md cross-check skipped."

## Step 6 — Report

Tell the user (or the calling `dream` skill) the overview file path, counts (auto-applied
/ flagged), and remind them the flagged items need `Status: APPROVED` before `dream` will
apply them.

## Scripts

- `scripts/find-claude-md-files.sh <real-project-path>` — Step 2.3: root + subdirectory
  CLAUDE.md discovery for one project.
- `scripts/find-memory-issues.sh <project-memory-dir>` — Step 2.2: dead `MEMORY.md` index
  lines and near-miss vs. unresolved `[[wikilink]]` classification for one project.

## Assets

- `assets/overview-template.md` — the Memory Improvement Overview skeleton, including the
  exact `Status:` marker contract `dream` depends on. Read and fill it in Step 5.

## Gotchas

- **This skill is global/repo-managed** — always invoke its scripts by the absolute
  `~/.claude/skills/improve-memory/scripts/...` path shown when the skill launches, never
  a bare `scripts/...` (resolves against the wrong cwd — same recurring mistake documented
  in `session-closer`'s and `save-memory`'s Gotchas).
- **A `WIKILINK_UNRESOLVED` finding is not a bug.** `save-memory` deliberately allows
  linking to a memory that doesn't exist yet, as a marker for "worth writing later." Only
  `WIKILINK_NEAR_MISS` (a link that clearly matches an existing file under a different
  hyphen/underscore spelling) is a real staleness fix — unresolved links are almost always
  intentional forward-references or references to skill names, not memory slugs at all
  (e.g. `[[bump-input]]`, `[[pin-input]]`), and should not be touched. The
  near-miss-vs-unresolved classification method itself is confirmed sound against this
  repo's own memory dir (checked repeatedly, most recently 2026-09-04, after `dream`'s
  first full-history run had already normalized the near-misses found on 2026-09-03) —
  don't expect any specific count to still be reproducible; re-run
  `scripts/find-memory-issues.sh` live rather than trusting a cached number here.
- **Don't blur the CLAUDE.md/contradiction/deletion line into auto-apply "for convenience"
  even when a fix looks obviously safe.** These are AI-generated edits to files the user
  relies on every session (or, for CLAUDE.md, files that change Claude's own behavior) —
  the flag tier exists specifically so a human sees them before they land, no matter how
  confident the proposed fix looks.
