---
name: refresh-manager-profile
description: Re-mine Claude Code session transcripts across all known projects for new decision-making/style signal since the last run, and update ~/.claude/manager-profile.md — the profile the `manager` agent uses to decide on the user's behalf. Use when the user says "refresh the manager profile", "update my manager's profile", "/refresh-manager-profile", or asks to re-mine transcripts for the manager agent.
---

# Refresh Manager Profile

On-demand incremental refresh of the `manager` agent's profile (`dotfiles/bosko/claude/manager-profile.md`, symlinked to `~/.claude/manager-profile.md`). Mines only transcript activity since the last time this skill ran per project — never a full re-mine — the same since-last-run idiom `skill-suggestion`/`skill-upgrade`/`skill-audit` already use.

## Steps

### 1. Discover the scan universe

The profile draws on every project this user has run Claude Code in, not a fixed list — new projects should be picked up automatically:

```bash
echo "$HOME/NixOS"
for d in "$HOME"/projects/*/; do echo "${d%/}"; done
```

For each resulting project directory, this is a candidate — not every one will have transcript history (some are throwaway or predate Claude Code use there).

### 2. Get a per-project cutoff and file list

For each candidate project directory:

```bash
CUTOFF=$(~/.claude/skills/lib/find-last-skill-invocation.sh refresh-manager-profile "<project-dir>")
~/.claude/skills/lib/list-transcripts-since.sh "$CUTOFF" "<project-dir>"
```

A project with no transcript directory fails soft (empty output) — skip it. A project with an empty file list has nothing new since last refresh — skip it too; don't pad the run by re-mining it. Only projects with a non-empty new-file list proceed to step 3. If **every** project comes back empty (including on a first-ever run, where `find-transcript-dir.sh` may simply find nothing new since the initial full mining pass), report that plainly and stop — there's nothing to update.

### 3. Fan out mining across projects with new activity

For each project with new files, spawn one `transcript-scanner` agent, passing it the explicit file list from step 2 (not a project-dir for it to resolve itself — you already have the exact scope). Ask it the same rubric the initial profile build used:

- Decision-making style (thorough vs. easier path, what tipped the balance)
- Risk tolerance & caution triggers (what got waved through vs. what stopped for confirmation)
- Values/priorities repeated across sessions
- Communication/reporting style
- Technical philosophy (root-cause vs. patch, when it reaches for a sub-agent/skill)
- Any explicit standing rule stated for how a delegate/agent should behave
- For family/shared-stakes projects (`FamDash`, `natalie`, `home-improvement`): how the user handles decisions affecting others

Same rules as the original mining pass: distilled, paraphrased traits with brief evidence — never raw transcript dumps, never verbatim sensitive/financial/family content. These are genuinely independent (disjoint project scopes) — run them concurrently, one call, per the standing parallelization rule.

### 4. Merge into the existing profile

Read the current `dotfiles/bosko/claude/manager-profile.md`. For each new finding:
- If it corroborates an existing trait, strengthen that trait's evidence rather than duplicating the section.
- If it's genuinely new signal, add it under the right section.
- If it contradicts an existing trait, don't silently overwrite — note the tension and prefer the more recent/more specific evidence, same as you'd reconcile any other stale-vs-fresh signal.

Keep the file distilled and bounded — this is a decision-making profile, not an archive. If a merge would make a section sprawl, tighten it rather than letting it grow unbounded.

### 5. Land it

Check whether this profile has ever been pushed before: `git log --oneline -- dotfiles/bosko/claude/manager-profile.md` in the NixOS repo.

- **First-ever push** (empty log): this is the sign-off case. Show the user the diff and get explicit confirmation via `AskUserQuestion` before committing — per the standing rule that the *initial* profile content requires a human read-through, since it's personal, irreversible once public, and not an ordinary call `manager` should make unsupervised.
- **Every subsequent refresh** (non-empty log): commit and push automatically, no sign-off gate — that step is a one-time exception, not a standing one.

Either way: run `public-repo-guard` before pushing (this file lands in a public repo) — hard gate, don't push if it doesn't come back clean. Then use `commit-and-push` with a conventional commit message (`chore(manager): refresh profile from N project(s)` or similar).

### 6. Report

State plainly: which projects had new activity, how many new traits/corroborations were added vs. how many were skipped as duplicates, and whether it pushed automatically or is waiting on sign-off.

## Gotchas

- Don't re-derive `find-transcript-dir.sh`'s slug math by hand to enumerate "all projects with history" — it's a lossy one-way transform (literal hyphens in directory names like `home-lab`/`random-searches` are indistinguishable from path separators once slugified). Always discover candidates from the real filesystem (step 1) and let the script resolve each one forward, not the reverse.
- A project that shows up in step 1 but has no `~/.claude/projects/<slug>/` directory at all (never opened in Claude Code, or opened only outside this flow) is not an error — skip it silently, don't report it as a gap.
