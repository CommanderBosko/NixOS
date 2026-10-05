---
name: refresh-manager-profile
description: Re-mine Claude Code session transcripts across all known projects for new decision-making/style signal since the last run, and update ~/.claude/manager-profile.md — the profile the `manager` agent uses to decide on the user's behalf. Use when the user says "refresh the manager profile", "update my manager's profile", "/refresh-manager-profile", or asks to re-mine transcripts for the manager agent.
---

# Refresh Manager Profile

On-demand incremental refresh of the `manager` agent's profile (`dotfiles/bosko/claude/manager-profile.md`, symlinked to `~/.claude/manager-profile.md`). Defaults to mining only transcript activity since the last time this skill ran per project — the same since-last-run idiom `skill-suggestion`/`skill-upgrade`/`skill-audit` already use — but falls back to a full re-mine for a project when there's a specific reason the incremental pass could have missed something (e.g. right after fixing a bug in the incremental-scan logic itself, or on explicit user request).

## Arguments

Optional: a request for a full re-mine instead of the incremental since-last-run scan (e.g. "fully re-mine the manager profile", or "re-mine <project>" to scope it to one project). When given, run the script with `full` (or `full <project-path>`) so it uses an empty cutoff for the affected project(s) instead of the discovered one. With no argument, every project runs its normal incremental scan.

## Steps

### 1–2. Discover projects and per-project file lists

Steps 1–2 are mechanical, so a script does them: it enumerates every project this user has run Claude Code in (via `list-all-projects.sh`, which reads each transcript's real `cwd` rather than un-slugifying directory names, skipping `UNKNOWN` rows), finds each project's cutoff, and lists transcripts newer than it.

```bash
~/.claude/skills/refresh-manager-profile/scripts/list-new-activity.sh [full [<project-path>]]
```

No argument = incremental scan of every project. `full` = empty cutoff for every project; `full <project-path>` = empty cutoff for that one project only (use for a user-requested full re-mine, or right after fixing the incremental-scan logic itself). Output is `PROJECT<TAB><path><TAB><cutoff>` followed by `FILE<TAB><name>` lines per project; projects with nothing new are omitted. Only projects that appear proceed to step 3. If the output is empty, report that plainly and stop — there's nothing to update. (Not every candidate has history worth mining; a project with no transcript dir is silently skipped.)

### 3. Fan out mining across projects with new activity

For each project with new files, spawn one `transcript-scanner` agent, passing it the explicit file list from steps 1–2 (not a project-dir for it to resolve itself — you already have the exact scope). Ask it the same rubric the initial profile build used:

- Decision-making style (thorough vs. easier path, what tipped the balance)
- Risk tolerance & caution triggers (what got waved through vs. what stopped for confirmation)
- Values/priorities repeated across sessions
- Communication/reporting style
- Technical philosophy (root-cause vs. patch, when it reaches for a sub-agent/skill)
- Any explicit standing rule stated for how a delegate/agent should behave
- For family/shared-stakes projects (the list lives in `agents/manager.md`'s "Shared-stakes carve-out" — don't re-list it here): how the user handles decisions affecting others

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

- Don't re-derive `find-transcript-dir.sh`'s slug math by hand to enumerate "all projects with history" — it's a lossy one-way transform (literal hyphens in directory names like `home-lab`/`random-searches` are indistinguishable from path separators once slugified). Always discover candidates from the real filesystem (the script) and let it resolve each one forward, not the reverse.
- A project that shows up in the script output but has no `~/.claude/projects/<slug>/` directory at all (never opened in Claude Code, or opened only outside this flow) is not an error — skip it silently, don't report it as a gap.
