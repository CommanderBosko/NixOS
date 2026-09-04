---
name: dream
description: Orchestrates the long-term-memory improvement suite -- applies any previously-approved memory/CLAUDE.md fixes, then (in full mode) runs a fresh session-analysis + improve-memory pass and reports results to Discord via send-results. Use when the user says "/dream", "run dream", "mine my sessions for memory", "check for approved memory fixes", or "improve my Claude memory".
---

# Dream

The orchestrator for the memory-improvement suite: `session-analysis` (mine all project
transcripts) → `improve-memory` (reconcile against real memory + CLAUDE.md files, produce
a Memory Improvement Overview) → `send-results` (report to Discord). `dream` ties these
together and keeps a run log so repeat runs are incremental, not full-history every time.

**Never blocks on an interactive prompt.** Approval is entirely file-based — the
`Status:` marker line in the last overview file, hand-edited by the user between runs —
so this skill can run unattended (on-demand today; schedule-ready later without any
change needed).

## Arguments

Invocation shape: `[--mode full|apply-fixes]`. Default: `full`.

- **`--mode full`** — (a) apply whatever's already approved in the last overview (Phase
  A below), **then** (b) run a fresh analysis pass regardless of what Phase A found
  (Phase B below). Two separate things happen even if Phase A had nothing to apply.
- **`--mode apply-fixes`** — Phase A only. No new analysis pass. For "did anything get
  approved since last time" checks without paying for a full mining pass.

## Step 0 — Load state

```bash
~/.claude/skills/dream/scripts/dream-state.sh init   # ensures ~/.claude/dream/ + run-log.json exist
~/.claude/skills/dream/scripts/dream-state.sh get    # current run log contents
```

The run log tracks: the last overview file processed, the overview status last observed,
timestamps of the last full run and last apply, and a history list. Treat the **overview
file's own `Status:` line as authoritative**, not the run log's cached
`last_overview_status_seen` — the user edits the file by hand between runs, so re-read it
fresh every time rather than trusting a stale cached copy.

## Phase A — Apply approved fixes (both modes)

1. Read `last_overview_file` from the run log. If it's `null` (no overview has ever been
   produced), there's nothing to apply — skip to Phase B (full mode) or stop (apply-fixes
   mode), and say so plainly rather than silently doing nothing.
2. Otherwise re-check its live status:
   ```bash
   ~/.claude/skills/dream/scripts/dream-state.sh overview-status <last_overview_file>
   ```
3. Branch on the result:
   - **`APPROVED`** — apply it (see below), then:
     ```bash
     ~/.claude/skills/dream/scripts/dream-state.sh record-apply <overview_file> applied
     ```
     (this also rewrites the overview file's own `Status:` line to `APPLIED`). Report the
     result:
     ```
     Skill send-results: <overview_file> "<one-line summary of what was applied>"
     ```
   - **`PENDING_REVIEW`** — nothing to do. Note it's still awaiting review.
   - **`REJECTED`** — nothing to do. Note it was declined; don't re-surface it as pending.
   - **`APPLIED`** — already done in a previous run; no-op, no need to re-report.
   - **`MISSING`** (no `Status:` line at all — a malformed file) — flag this as an
     anomaly in the final report rather than silently ignoring it.

### Applying an `APPROVED` overview

Read the overview file's "Flagged for Review" section. Each numbered item
(`### F1`, `F2`, ...) already states its **exact** proposed change — `improve-memory`
wrote it that way specifically so this step is mechanical execution, not a fresh judgment
call. For each item: make the literal edit it describes (create/edit a subdirectory
CLAUDE.md, edit the root CLAUDE.md pointer line, delete a superseded memory file, resolve
a contradiction the way it specifies). If an item's proposed change is genuinely
ambiguous or missing the literal content needed to apply it mechanically, skip just that
item, leave it flagged, and say so in the report — don't improvise a fix `improve-memory`
never actually proposed.

**This skill edits files directly; it does not `git commit` or `git push`.** A CLAUDE.md
change can land inside a git-tracked project (this repo included) — leave it as a
worktree diff for a human to review and commit, same as any other agent-authored edit to
a file the user relies on every session. Don't add a commit step here even under
`--mode full` running unattended later.

## Phase B — Fresh analysis pass (`--mode full` only)

1. Determine the since-cutoff: the run log's `last_full_run_at`, or omitted entirely if
   this is the first-ever full run (full history).
2. Run the mining pass:
   ```
   Skill session-analysis: dream <since-cutoff-or-omitted>
   ```
   → produces `~/.claude/dream/analysis-<ts>.md`.
3. Reconcile it:
   ```
   Skill improve-memory: <analysis-file-from-step-2>
   ```
   → produces a new `~/.claude/dream/overview-<ts>.md` with `Status: PENDING_REVIEW`.
4. Record it:
   ```bash
   ~/.claude/skills/dream/scripts/dream-state.sh record-full-run <analysis_file> <overview_file>
   ```
5. Report it:
   ```
   Skill send-results: <overview_file> "<one-line summary: N projects scanned, M candidate items, X auto-applied, Y flagged for review — review and set Status: APPROVED to apply>"
   ```

## Step Final — Summarize

Tell the caller what happened in each phase that ran: whether anything was applied (and
what), and whether a new analysis pass ran (and its headline numbers). If `send-results`
failed (e.g. the Discord webhook secret isn't configured yet — see `send-results`'s Setup
section), say so plainly; a failed notification is not the same as a failed run, but don't
let it pass silently either.

## Scripts

- `scripts/dream-state.sh init|get|latest-overview|overview-status|record-full-run|record-apply`
  — all the deterministic run-log and overview-status mechanics (Steps 0, A, B). See its
  own header comment for exact subcommand usage. JSON read-modify-write is centralized
  here rather than asking the model to hand-edit `run-log.json`.

## Gotchas

- **This skill is global/repo-managed** — always invoke `dream-state.sh` by the absolute
  `~/.claude/skills/dream/scripts/...` path shown when the skill launches, never a bare
  `scripts/...` path.
- **Re-read the overview file's `Status:` line fresh every run, never trust the run log's
  cached `last_overview_status_seen` as current** — the whole point of the marker is that
  a human edits the file between runs, and the run log is only updated *after* dream acts
  on what it sees.
- **First-ever run has no `last_overview_file`** — Phase A has nothing to apply, which is
  expected, not an error. Don't skip Phase B because of it in `--mode full`.
- **A `--mode apply-fixes` run that finds nothing approved is a normal, successful
  no-op** — report it as "checked, nothing approved yet," not as a failure.
