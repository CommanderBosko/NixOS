---
name: improve-system
description: One command to upgrade the whole Claude ecosystem — chains skill-upgrade, skill-suggestion, agent-suggestion, claude-rules, skill-audit, and fewer-permission-prompts into a single pass, auto-applying low-risk additive fixes and confirming structural ones, then reports the consolidated summary to Discord via send-results. Use when the user says "improve-system", "/improve-system", "upgrade my Claude setup", "improve my system", "tune up my skills", or "run a Claude ecosystem sweep".
---

# Improve System

A single orchestrator that runs your six Claude-ecosystem maintenance skills in one pass, leaves the setup healthier than it found it, and reports the outcome to Discord. It **coordinates** the underlying skills — it does not reimplement them, so each stays independently runnable and there is no logic drift.

(Bucket: Orchestration — its job is to sequence and gate other skills, not to do their work. Invoke each sub-skill via the Skill tool; never copy its steps inline.)

## Operating mode: auto-apply low-risk, confirm structural

Classify every proposed change before acting:

- **Low-risk (auto-apply, then report what you did):** purely *additive, reversible, non-destructive* edits to files that already exist —
  - `## Gotchas` entries added by **skill-upgrade**
  - the five standing workflow rules added to `CLAUDE.md` by **claude-rules**
  - `permissions.allow` additions in `settings.json` from **fewer-permission-prompts**
- **Structural (always confirm first via the AskUserQuestion tool):** anything that creates files, changes behaviour, deletes/rewrites content, or needs new wiring + a rebuild —
  - a **new skill** proposed by skill-suggestion (new file + `bosko-claude.nix` symlink + rebuild)
  - a **new custom agent** proposed by agent-suggestion (new `.claude/agents/*.md` file + `bosko-claude.nix` symlink + rebuild + an edited call-site skill)
  - skill-audit's "fix it" refactors (script/asset extraction, drift fixes, splits)
  - any `permissions.deny`/`ask` or hook change

For every structural item, use the **AskUserQuestion** tool rather than a prose question — present the specific proposed change with options **Approve** (apply it) and **Skip** (leave it alone), one question per item (or a batched multi-question call when several independent structural items are pending at once). When in doubt, treat it as structural and ask via AskUserQuestion.

## Step 1 — Session-reactive pass (uses *this* conversation)

These three mine the current session, so run them while it's fresh.

1. **skill-upgrade** — invoke the `skill-upgrade` skill. It finds skills that misfired this session and drafts `## Gotchas`. **Auto-apply** the gotchas (low-risk), then list each skill hardened and the gotcha added. If nothing misfired, it says so — carry that forward.
2. **skill-suggestion** — invoke the `skill-suggestion` skill. It ranks and lists every candidate skill that clears its reuse bar (not just one) worth capturing from this session. Building a new skill is **structural** → present each candidate's proposal, then use the **AskUserQuestion** tool (multi-select if there's more than one) with options **Approve** (hand off to `new-skill`) and **Skip** (don't build it), per candidate. If the session has no reusable workflow, it stops cleanly.

   After `new-skill` writes the file, **smoke-test it** before folding it into the consolidated report: invoke the new skill once via the Skill tool against a safe, low-risk, or read-only scenario that exercises its documented steps end to end (mirrors `ship-skill`'s Step 3, without adopting its per-skill commit/push). Report pass/fail plainly, including anything that diverged from what the SKILL.md describes. If it fails, fix the skill file and re-test before Step 3's report — don't carry a known-broken skill into the consolidated commit. This is why `new-skill` is used here rather than `ship-skill`: `ship-skill` bundles its own commit and a push-confirmation pause per skill, which would fragment the single end-of-run commit this orchestrator already makes across all its findings, and interrupt the batch flow across the remaining steps.
3. **agent-suggestion** — invoke the `agent-suggestion` skill. It proposes custom sub-agents (`.claude/agents/*.md`) worth extracting from recurring `Agent`-tool spawn patterns in this session and recent transcripts. Building a new agent is **structural** → for each candidate, use the **AskUserQuestion** tool with options **Approve** (let it build the agent + rewire the named call site) and **Skip**, per candidate. Unlike skill-suggestion, `agent-suggestion` builds inline itself (writes the agent file, adds the `bosko-claude.nix` entry, edits the call-site skill) rather than handing off to a separate builder skill — there's no per-candidate commit/push bundled in, so it stays compatible with this orchestrator's single end-of-run commit. If nothing in the window clears its fit heuristic, it stops cleanly — carry that forward as a clean pass.

   After it builds an agent, **smoke-test it** before folding it into the consolidated report: spawn it once via the `Agent` tool (`subagent_type: "<name>"`) against a safe, read-only scenario that exercises its documented job, and confirm the edited call-site skill still reads sensibly. Report pass/fail plainly. If it fails, fix the agent file (or revert the call-site edit) and re-test before Step 3's report — don't carry a known-broken agent into the consolidated commit.

## Step 2 — Proactive sweep (whole repo / setup)

4. **claude-rules** — invoke the `claude-rules` skill against this project's `CLAUDE.md`. Adding any missing standing rule is **low-risk** → auto-apply, then report which rules were already present vs added.
5. **skill-audit** — invoke the `skill-audit` skill. It is report-only by design. Surface its prioritized findings (correctness bugs first). Auto-apply **only** trivially-additive fixes if any; for every structural refactor it recommends, use the **AskUserQuestion** tool (one question per refactor, or batched per item) with options **Approve** (apply the refactor) and **Skip** (leave it as a reported finding) before saying "fix it". Do not silently run its full fix pass.
6. **fewer-permission-prompts** — invoke the `fewer-permission-prompts` skill. Adding entries to `permissions.allow` is **low-risk** → auto-apply, but **show the exact list added** so the user can object. Never auto-add `deny`/`ask` or hooks — if such a change is ever surfaced as a candidate, treat it as structural and confirm via **AskUserQuestion** (options **Approve** / **Skip**) rather than applying it silently.

## Step 3 — One consolidated report

After all six, print a single summary, not six scattered ones:

- **Applied (low-risk):** gotchas added, rules added, allow-list entries added — each with the file touched.
- **Awaiting your call (structural):** new-skill proposal (with its smoke-test result), new-agent proposal (with its smoke-test result and the call site it would rewire), skill-audit refactors, anything needing a rebuild — listed so the user can approve in one place.
- **Clean:** the passes that found nothing (say so explicitly — a clean pass is a result).

## Step 4 — Certify + remind

Several of these skills edit **repo-managed global skills** under `dotfiles/bosko/claude/skills/` (skill-upgrade, a new skill from skill-suggestion) or **repo-managed global agents** under `dotfiles/bosko/claude/agents/` (a new agent from agent-suggestion, plus its edited call-site skill). After any such edit:

- Run the `nixos-dry-run` skill to prove the flake still evaluates.
- Remind the user that repo-managed skill/agent edits only reach `~/.claude` after `nh os boot /home/bosko/NixOS` **and a reboot** (it only stages the change for next boot — there's no live `nh os switch` in the normal flow here). No new session is needed beyond that — the symlink resolves in the same running session as soon as it's updated, since skill/agent discovery reads from disk per-invocation.
- A brand-new skill or agent also needs its `home.file` symlink entry added to `dotfiles/bosko/bosko-claude.nix` before the rebuild.

## Step 5 — Report to Discord

Always runs, even on a focus-argument partial pass and even when every step came back clean — a clean pass is a result worth reporting, not a reason to skip the notification.

1. Write the Step 3 consolidated report (applied / awaiting-your-call / clean), plus Step 4's certify status if it ran, to `~/.claude/improve-system/report-<ts>.md` (`<ts>` = `date +%Y%m%d-%H%M%S`; create the directory if it doesn't exist). This is the same content already shown in chat — just captured to a file so `send-results` has something to publish.
2. Hand it off:
   ```
   Skill send-results: <report-file> "<one-line summary: N low-risk fixes applied, M structural items awaiting approval, rest clean>"
   ```
3. If `send-results` fails (e.g. the Discord webhook secret isn't configured — see its own Setup section), report that plainly to the user — a failed notification is not the same as a failed sweep, but don't let it pass silently.

## Arguments

Optional focus argument in the user's phrasing — e.g. "improve-system, skills only" or "improve-system, just permissions". If given, run only the matching sub-skills — **skills-only** = `skill-upgrade` + `skill-suggestion` + `agent-suggestion` + `skill-audit` (plus Step 4's certify/remind); **permissions** = `fewer-permission-prompts`; **rules** = `claude-rules`. With no argument, run all six. Step 5 (Discord report) still runs regardless of focus scope.

## Gotchas

- **Don't reimplement the sub-skills.** This is an orchestrator; invoke each via the Skill tool. If you find yourself writing audit logic or drafting gotchas by hand, you've drifted out of bucket.
- **Auto-apply means *additive only*.** A change that rewrites or deletes existing content is structural even if it "feels safe" — confirm it.
- **Repo-managed skill edits don't take effect live.** They need a rebuild + new session; never report a hardened global skill as "active now."
- **This skill is itself repo-managed.** It must be in `bosko-claude.nix`'s `home.file` list and rebuilt before its `~/.claude/skills/improve-system` symlink appears.
- **`fewer-permission-prompts` (Step 2, item 6) has emitted invalid `settings.json`.** Observed across past sessions: it wrote permission entries with empty parentheses (e.g. `Bash()`), which fail Claude Code settings validation (`permissions.deny.N: Empty parentheses`), and it shelled out to `jq`/`python3` that returned `command not found` on this host. When orchestrating this step, auto-apply only concrete non-empty `permissions.allow` strings, drop any empty-paren entry before writing, and don't assume `jq` is on PATH.
- **A "nothing to act on" verdict must be earned by actually checking the logs, not inferred from context.** Asked in passing whether a pass was worth running, a prior response guessed "session was small, no friction" purely from what was still visible in the conversation, without invoking `skill-upgrade`'s transcript-grep step (`~/.claude/projects/<slug>/*.jsonl`) — it read as a real assessment but wasn't one. A "no work needed" conclusion is a perfectly fine outcome, but it must always follow from actually running that check first — never state a verdict, even offhand, as if the check happened when it didn't.
- **`send-results` publishes the report as a Claude Artifact, which leaves the local machine.** Same trade-off `send-results` itself documents — the consolidated report (skill names, file paths, proposed changes) becomes a shareable `https://` link, starting private but cacheable once shared. That's expected for this step, not a bug; don't route Step 5 through anything else to avoid it.
