---
name: improve-system
description: One command to upgrade the whole Claude ecosystem — chains skill-upgrade, skill-suggestion, claude-rules, skill-audit, and fewer-permission-prompts into a single pass, auto-applying low-risk additive fixes and confirming structural ones. Use when the user says "improve-system", "/improve-system", "upgrade my Claude setup", "improve my system", "tune up my skills", or "run a Claude ecosystem sweep".
---

# Improve System

A single orchestrator that runs your five Claude-ecosystem maintenance skills in one pass and leaves the setup healthier than it found it. It **coordinates** the underlying skills — it does not reimplement them, so each stays independently runnable and there is no logic drift.

(Bucket: Orchestration — its job is to sequence and gate other skills, not to do their work. Invoke each sub-skill via the Skill tool; never copy its steps inline.)

## Operating mode: auto-apply low-risk, confirm structural

Classify every proposed change before acting:

- **Low-risk (auto-apply, then report what you did):** purely *additive, reversible, non-destructive* edits to files that already exist —
  - `## Gotchas` entries added by **skill-upgrade**
  - the four standing workflow rules added to `CLAUDE.md` by **claude-rules**
  - `permissions.allow` additions in `settings.json` from **fewer-permission-prompts**
- **Structural (always confirm first):** anything that creates files, changes behaviour, deletes/rewrites content, or needs new wiring + a rebuild —
  - a **new skill** proposed by skill-suggestion (new file + `bosko-claude.nix` symlink + rebuild)
  - skill-audit's "fix it" refactors (script/asset extraction, drift fixes, splits)
  - any `permissions.deny`/`ask` or hook change

When in doubt, treat it as structural and ask.

## Step 1 — Session-reactive pass (uses *this* conversation)

These two mine the current session, so run them while it's fresh.

1. **skill-upgrade** — invoke the `skill-upgrade` skill. It finds skills that misfired this session and drafts `## Gotchas`. **Auto-apply** the gotchas (low-risk), then list each skill hardened and the gotcha added. If nothing misfired, it says so — carry that forward.
2. **skill-suggestion** — invoke the `skill-suggestion` skill. It proposes at most one new skill worth capturing from this session. Building a new skill is **structural** → present its proposal and **confirm** before it hands off to `new-skill`. If the session has no reusable workflow, it stops cleanly.

## Step 2 — Proactive sweep (whole repo / setup)

3. **claude-rules** — invoke the `claude-rules` skill against this project's `CLAUDE.md`. Adding any missing standing rule is **low-risk** → auto-apply, then report which rules were already present vs added.
4. **skill-audit** — invoke the `skill-audit` skill. It is report-only by design. Surface its prioritized findings (correctness bugs first). Auto-apply **only** trivially-additive fixes if any; for every structural refactor it recommends, **confirm** before saying "fix it". Do not silently run its full fix pass.
5. **fewer-permission-prompts** — invoke the `fewer-permission-prompts` skill. Adding entries to `permissions.allow` is **low-risk** → auto-apply, but **show the exact list added** so the user can object. Never auto-add `deny`/`ask` or hooks.

## Step 3 — One consolidated report

After all five, print a single summary, not five scattered ones:

- **Applied (low-risk):** gotchas added, rules added, allow-list entries added — each with the file touched.
- **Awaiting your call (structural):** new-skill proposal, skill-audit refactors, anything needing a rebuild — listed so the user can approve in one place.
- **Clean:** the passes that found nothing (say so explicitly — a clean pass is a result).

## Step 4 — Certify + remind

Several of these skills edit **repo-managed global skills** under `dotfiles/bosko/claude/skills/` (skill-upgrade, a new skill from skill-suggestion). After any such edit:

- Run the `nixos-dry-run` skill to prove the flake still evaluates.
- Remind the user that repo-managed skill edits only reach `~/.claude` after `nh os boot /home/bosko/NixOS` **and a new session** — the live session keeps using the old `/nix/store` path.
- A brand-new skill also needs its `home.file` symlink entry added to `dotfiles/bosko/bosko-claude.nix` before the rebuild.

## Arguments

Optional focus argument in the user's phrasing — e.g. "improve-system, skills only" or "improve-system, just permissions". If given, run only the matching sub-skills (skills-only = steps 1, 2, 4; permissions = step 5; rules = step 3·claude-rules). With no argument, run all five.

## Gotchas

- **Don't reimplement the sub-skills.** This is an orchestrator; invoke each via the Skill tool. If you find yourself writing audit logic or drafting gotchas by hand, you've drifted out of bucket.
- **Auto-apply means *additive only*.** A change that rewrites or deletes existing content is structural even if it "feels safe" — confirm it.
- **Repo-managed skill edits don't take effect live.** They need a rebuild + new session; never report a hardened global skill as "active now."
- **This skill is itself repo-managed.** It must be in `bosko-claude.nix`'s `home.file` list and rebuilt before its `~/.claude/skills/improve-system` symlink appears.
- **Step 5 (`fewer-permission-prompts`) has emitted invalid `settings.json`.** Observed across past sessions: it wrote permission entries with empty parentheses (e.g. `Bash()`), which fail Claude Code settings validation (`permissions.deny.N: Empty parentheses`), and it shelled out to `jq`/`python3` that returned `command not found` on this host. When orchestrating Step 5, auto-apply only concrete non-empty `permissions.allow` strings, drop any empty-paren entry before writing, and don't assume `jq` is on PATH.
- **A "nothing to act on" verdict must be earned by actually checking the logs, not inferred from context.** Asked in passing whether a pass was worth running, a prior response guessed "session was small, no friction" purely from what was still visible in the conversation, without invoking `skill-upgrade`'s transcript-grep step (`~/.claude/projects/<slug>/*.jsonl`) — it read as a real assessment but wasn't one. A "no work needed" conclusion is a perfectly fine outcome, but it must always follow from actually running that check first — never state a verdict, even offhand, as if the check happened when it didn't.
