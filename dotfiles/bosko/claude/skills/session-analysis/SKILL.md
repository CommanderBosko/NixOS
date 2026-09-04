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

If `<mode>` is missing, ask what to scan rather than guessing.

## Why cross-project mining needs its own lib script

`find-transcript-dir.sh` / `list-transcripts-since.sh` / `find-last-skill-invocation.sh`
(in `~/.claude/skills/lib/`) all have a **single-project** contract: given one project
directory, resolve to its one transcript dir. Other skills (`session-closer`,
`skill-suggestion`, `skill-upgrade`, `skill-audit`, `save-memory`, `research`) depend on
that contract staying exactly as-is. So mining all projects uses a **new** script,
`list-all-projects.sh`, that enumerates every dir under `~/.claude/projects/*/` and prints
each one's real project path (recovered from the `cwd` field inside a `.jsonl` transcript,
not by un-slugifying the directory name -- see its header comment for why that's not safe)
paired with its transcript dir. Because it prints the *real path*, callers can still feed
that straight into `list-transcripts-since.sh` unchanged instead of forking its contract.

A project dir with no `.jsonl` files left (transcripts pruned, only a `memory/` dir
remains) prints `UNKNOWN` as its real path. Skip mining for it — there's nothing to mine —
but don't drop it silently from the manifest; `improve-memory` still wants to know it
exists for the memory-hygiene pass.

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
- **Spawn every batch across every project in a single message** (the CLAUDE.md
  parallelization rule) — projects are fully independent of each other, and batches within
  one project are independent of each other too.
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
still valid ISO-8601 basic format). Shape:

```markdown
# Session Analysis — dream — <human-readable date>

Since: <since-timestamp, or "full history">
Projects scanned: <N total> (<M> memory-only / no transcripts)

## Project: /home/bosko/NixOS

- [decision] <one-line finding, self-contained>
- [gotcha] <...>

## Project: /home/bosko/projects/bitburner

(no candidate findings this pass)

## Project: UNKNOWN (transcript dir: ~/.claude/projects/-home-bosko-projects-farmer)

(memory-only project — no transcripts to mine)
```

Keep one project section per project found in the manifest, even ones with nothing found
or nothing to mine — `improve-memory` uses the full project list, not just the ones with
findings, to know which memory dirs and CLAUDE.md trees to cross-check next.

### Step 4 — Report

Tell the user (or the calling `dream` skill) the analysis file path, the project/transcript
counts, and the total candidate-item count. Do not judge auto-apply vs. flag tiers here —
that reconciliation against existing memory is `improve-memory`'s job entirely.

## Mode: `time-analysis` (not yet built)

Reserved. When this is built, add a `time-analysis)` case arm to `scripts/scan-projects.sh`
alongside `dream)`, and a matching `## Mode: time-analysis` section here — don't change
`dream` mode's behavior to accommodate it.

## Scripts

- `scripts/scan-projects.sh <mode> [since-iso-timestamp]` — mode dispatch + manifest
  (Step 1). Depends on the shared `~/.claude/skills/lib/list-all-projects.sh` and
  `list-transcripts-since.sh`.

## Gotchas

- **This skill is global/repo-managed** (source at
  `dotfiles/bosko/claude/skills/session-analysis/` in the NixOS repo, symlinked to
  `~/.claude/skills/session-analysis/` via Home Manager). Always invoke
  `scripts/scan-projects.sh` by the absolute `~/.claude/skills/session-analysis/scripts/...`
  path shown when the skill launches, never a bare `scripts/...` — that resolves against
  whatever project happens to be the cwd, not this skill's own directory (the same
  recurring mistake documented in `session-closer`'s and `save-memory`'s Gotchas).
- **A project's transcript count can be large** (observed: 87 for this repo, 95 for a
  long-running game project, out of full history with no since-cutoff). Don't hand a
  `transcript-scanner` agent an 80+ file batch — split into multiple ~10-15 file batches
  per project rather than one oversized agent call; it's still one message spawning all of
  them in parallel.
- **`UNKNOWN` real-path projects have zero transcripts by construction** (observed:
  4 of 12 local projects on 2026-09-03 had only a pruned `memory/` dir left, no `.jsonl` at
  all) — don't try to guess a real path for these via un-slugifying; the manifest already
  marks them, just skip mining and let `improve-memory` still see them for the memory-only
  hygiene pass.
