---
name: session-analysis
description: Mine Claude Code session transcripts across ALL projects (not just the current one) for memory-worthy content. Argument-dispatched by mode -- "dream" scans for durable facts/decisions/corrections/gotchas worth remembering; future modes slot in the same way. Use when the user says "/session-analysis dream", "mine all my session history", "scan every project for memory-worthy stuff", or when the `dream` skill invokes it as its analysis phase.
---

# Session Analysis

Cross-project transcript mining, dispatched by `<mode>`. Unlike `session-closer` /
`skill-suggestion` / `save-memory`'s own log-mining (which is scoped to whichever single
project's transcript dir the skill is currently running in), this skill sweeps **every**
project under `~/.claude/projects/*/` in one pass. It is the analysis phase the `dream`
orchestrator skill runs before `improve-memory`; it can also be invoked directly.

Only `dream` mode is implemented. The mode dispatch (in `scripts/scan-projects.sh` and the
Steps below) exists so a future `time-analysis` mode (or others) can be added as a new case
arm without touching `dream` mode's logic.

## Arguments

Invocation shape: `<mode> [since-iso-timestamp]`.

- **`<mode>`** (required) — `dream` (only mode built so far).
- **`[since-iso-timestamp]`** (optional) — an ISO-8601 timestamp; only transcripts with
  activity at or after this cutoff are mined. Omit for full history. The `dream` skill
  passes its run log's last-processed timestamp here so repeat runs aren't reprocessing
  the same ground; a first-ever run (or a direct manual invocation) should omit it.

If `<mode>` is missing, don't guess: ask via the **AskUserQuestion** tool with options
**dream** (mine every project for memory-worthy items) and **Cancel**. Add each newly built
mode as another option.

## Why cross-project mining needs its own lib script

Project enumeration uses `list-all-projects.sh`, not the single-project lib scripts, and an
`UNKNOWN` real-path project is skipped for mining but kept in the manifest. See
`references/why-cross-project.md` for why.

## Mode: `dream`

Goal: produce one **Session Analysis** file at `~/.claude/dream/analysis-<ISO8601>.md`
listing candidate memory-worthy items found across every project, grouped by project, for
`improve-memory` to reconcile against existing memory next.

### Step 1 — Build the manifest

```bash
~/.claude/skills/session-analysis/scripts/scan-projects.sh dream [since-iso-timestamp]
```

This creates `~/.claude/dream/` if it doesn't exist yet, then prints a manifest: one block
per project with its real path (or `UNKNOWN`), transcript dir, and the list of in-scope
transcript filenames (already cutoff-filtered if a since-timestamp was given).

### Step 2 — Fan out mining across projects in parallel

For every project block with `TRANSCRIPTS_IN_SCOPE` > 0, mine its listed transcripts using
the **`transcript-scanner`** sub-agent (`subagent_type: "transcript-scanner"`) — this is
the existing fan-out unit built exactly for "mine a batch of a project's transcripts for a
pattern," already used by `session-closer`/`skill-suggestion`/`skill-audit`.

- **Batch size**: keep each agent's file list to roughly 10-15 transcripts. A project with
  more than that (check the manifest's count) gets split into multiple sequential batches
  of its own file list, each run as a separate agent — don't hand one agent 80+ files.
- **Spawn batches in parallel waves of at most 20 agents per message, counted across all
  projects combined** (the CLAUDE.md parallelization rule, capped by the harness's
  20-concurrent-subagent limit — see `references/concurrency-cap-gotcha.md`). Projects are
  fully independent of each other, and batches within one project are too, so any batch can
  go in any wave. If the manifest needs more than 20, spawn a wave, let it complete, then
  spawn the next.
- **Brief each agent identically** except for its project path + file list: mine the given
  transcripts (full paths under the given transcript dir) for content worth remembering
  long-term, using the same judgment `save-memory`/`session-closer` already apply —
  durable facts, real decisions and their rationale, corrections ("no, actually do X not
  Y"), and gotchas/bugs-and-fixes. Explicitly exclude anything the project's own git
  history or code already records, and anything that only mattered to one conversation.
  Ask for each finding tagged as one of `fact` / `decision` / `correction` / `gotcha`, in
  one line each, with enough context to stand alone (a future reader won't have the
  conversation).

### Step 3 — Write the analysis file

Aggregate every sub-agent's findings into `~/.claude/dream/analysis-<ISO8601>.md`
(timestamp format: `date -u +%Y%m%dT%H%M%SZ`, e.g. `20260903T193000Z` — filesystem-safe,
still valid ISO-8601 basic format). Read `<skill-base-dir>/assets/analysis-template.md` and
fill it in — it holds the file's shape (header, Since/Projects-scanned lines, one
`## Project: <path>` section per project with its findings or a "nothing to mine" note).

Keep one project section per project found in the manifest, even ones with nothing found
or nothing to mine — `improve-memory` uses the full project list, not just the ones with
findings, to know which memory dirs and CLAUDE.md trees to cross-check next.

### Step 4 — Report

Tell the user (or the calling `dream` skill) the analysis file path, the project/transcript
counts, and the total candidate-item count. Do not judge auto-apply vs. flag tiers here —
that reconciliation against existing memory is `improve-memory`'s job entirely.

## Mode: `time-analysis` (not yet built)

Reserved future-mode scaffolding — see `references/planned-modes.md` before adding a new mode.

## Scripts

- `scripts/scan-projects.sh <mode> [since-iso-timestamp]` — mode dispatch + manifest
  (Step 1). Depends on the shared `~/.claude/skills/lib/list-all-projects.sh` and
  `list-transcripts-since.sh`.

## Assets

- `assets/analysis-template.md` — the `dream`-mode analysis file's shape (Step 3). Read and
  fill it; never rewrite the layout inline.

## Gotchas

- **Script paths:** use the absolute path from this skill's Base directory line, never a bare `scripts/...` — see `~/.claude/skills/lib/script-paths.md`.
- Transcript batch sizing (large projects) and `UNKNOWN` real-path projects: see `references/gotchas.md`.
- Fanning out `transcript-scanner` across multiple projects in one message? See `references/concurrency-cap-gotcha.md` for the 20-agent cap.
