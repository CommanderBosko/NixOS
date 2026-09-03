---
name: research
description: Web-search a topic, fan out parallel sub-agents to review the top results in depth, report back a synthesized consensus with source citations, and save it to memory (cross-referencing any prior research on the same topic). Use when the user says "research X", "/research X", "deep research on X", "look into X thoroughly", or "get me a consensus on X".
---

# Research

Runs a web search on a topic, spawns parallel sub-agents to each review one top result in detail, synthesizes their findings into a consensus report, and persists that report (sources, findings, consensus, and a fast/slow volatility tag) to memory via `save-memory` — cross-referencing any prior memory on the same topic along the way. (Bucket: Data Enrichment)

## Arguments

Invocation shape: `<topic>` or `<topic> <n>`.

- **`<topic>`** (required) — the subject to research. If omitted, ask the user for one before proceeding.
- **`<n>`** (optional) — the number of top results to review in depth. Defaults to **10** if omitted.

## Steps

1. **Parse arguments.** The invocation is `<topic>` or `<topic> <n>`, where `<n>` is an optional result count. Default `n` to 10 if omitted. If no topic is given, ask the user for one.

2. **Check for a prior memory on this topic.** Resolve the current project's memory dir:

   ```bash
   ~/.claude/skills/lib/find-transcript-dir.sh   # prints ~/.claude/projects/<slug>, or fails if none
   ```

   If it resolves, read `<that-dir>/memory/MEMORY.md` and scan its index for a line whose slug or
   description looks related to the topic (it will typically be a `reference_*` memory from a past
   `/research` run — see Step 7). If a candidate matches, read that memory file's body and carry its
   verdict, its `Researched: YYYY-MM-DD` date, and its `Volatility:` tag (see Step 7) forward into
   Step 6 for cross-referencing. If the transcript dir, memory dir, or `MEMORY.md` doesn't exist —
   this project has no memory system yet, or none is topically related — proceed without
   cross-referencing; this is not a failure.

3. **Search.** Run `WebSearch` on the topic. Collect up to `n` distinct, relevant result URLs from the results. If the search returns fewer than `n` usable results, proceed with what's available and note the shortfall in the final report — don't pad with irrelevant links.

4. **Spawn review agents in parallel.** In a single message, call the `Agent` tool `n` times (one per URL), each with `subagent_type: "source-reviewer"` (fresh agent — no shared context needed; the agent definition already knows how to fetch, extract, and report — see `dotfiles/bosko/claude/agents/source-reviewer.md`). Brief each one with just: the research topic/question, and the single URL it's responsible for.

5. **Collect results.** Wait for all sub-agents to report back. Tally how many of the `n` sources were actually usable vs. inaccessible.

6. **Synthesize a consensus report** and post it directly in chat (no artifact) with:
   - A short overall verdict / majority position on the topic.
   - Notable dissent or minority views, if any, and why they diverge (e.g. different assumptions, outdated info, niche context).
   - A source list: one line per source with its takeaway and a link.
   - A note on coverage, e.g. "8/10 sources reviewed successfully; 2 inaccessible (paywalled)."
   - If Step 2 surfaced a prior memory, a line stating whether this run **reaffirms**, **updates**, or **contradicts** it (and why) — including its age (e.g. "last researched 2026-03-01, ~5 months ago") and, if it carried one, its `Volatility` tag.

7. **Persist the findings to memory.** Once the report is posted, invoke the `save-memory` skill
   (via the `Skill` tool) to write or update one `reference`-type memory for this research topic —
   `save-memory` is global/repo-managed, same as `research` itself (see Gotchas), but confirm it's
   present in this project's available-skills list before invoking it (e.g. a machine that hasn't
   rebuilt since it was added); if it isn't, say plainly that no memory was saved for this project and
   move on rather than silently skipping. Hand `save-memory` a single fact whose body covers, in one file:
   - the consensus verdict (and any notable dissent) from Step 6;
   - the source list — one line per source with its link and takeaway;
   - a coverage note (n/m sources usable) and today's date as "Researched: YYYY-MM-DD";
   - a **volatility classification** — a `Volatility: fast — <one-line reason>` or
     `Volatility: slow — <one-line reason>` line, judged from the topic itself, not the sources
     found. Ask: does the true answer to this topic actually change over time (pricing, software
     versions/features, live service status, security advisories, current events, rankings/"best of"
     lists), or is it settled (historical fact, a definition, how something fundamentally works, a
     completed past event)? When genuinely unsure, default to `fast` — a stale-check that fires once
     too often is cheaper than one that silently never fires. This tag is what later lets a stale
     read of this memory (see the global CLAUDE.md's stale-research-memory rule) decide whether to
     suggest a refresh — get it right, and leave the one-line reason so the user can correct it by
     hand if it's wrong;
   - if Step 2 found a prior memory on the same topic, say so explicitly and state whether this run
     reaffirmed, updated, or contradicted it — `save-memory`'s own duplicate check (its Step 2) will
     then update that existing file instead of creating a near-duplicate.
   Relay back to the user which memory file `save-memory` wrote or updated.

8. **Edge cases:**
   - If every source is inaccessible, say so plainly instead of producing a synthesized verdict from nothing — and skip Step 7 (there's no finding worth persisting).
   - If sources genuinely conflict (not just differ in emphasis), state the conflict directly rather than forcing a false consensus.

## Gotchas

- **What went wrong:** Step 5's "wait for all sub-agents to report back" was read as "actively poll for completion," leading to three consecutive malformed `ScheduleWakeup` calls in one session (missing `prompt`, then missing `delaySeconds`/`reason`) before giving up on it.
- **How to avoid it:** don't call `ScheduleWakeup` to wait on sub-agents spawned via the `Agent` tool — that work is harness-tracked, so a completion notification arrives automatically as a later turn without any polling call. Just let the turn end after spawning; there is nothing to schedule.
- **`save-memory` isn't guaranteed available in every project** — it's global/repo-managed (symlinked into `~/.claude/skills/save-memory` via `bosko-claude.nix`'s `home.file`, from `dotfiles/bosko/claude/skills/save-memory`), the same mechanism as `research` itself, not a project-local skill. But a repo-managed skill only reaches `~/.claude` after a rebuild, so on a machine that hasn't rebuilt since it was added (or a non-Home-Manager machine) it may still be missing. Step 7 must check the available-skills list before invoking it, not assume it exists just because `research` does.
