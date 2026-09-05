---
name: agent-suggestion
description: Analyze the current conversation and session logs for Agent-tool spawns that are re-typed as prose every time, and propose (then build, on approval) a real custom sub-agent (.claude/agents/*.md) for the ones that qualify. Use when the user says "agent-suggestion", "suggest an agent", "build me a custom agent", "what agent would help here", or "find agent opportunities".
---

# Agent Suggestion

Mine the current conversation and recent session history for `Agent`-tool spawn patterns worth turning into a real custom sub-agent, propose the best candidates, and — on approval — build them. The direct analog of `skill-suggestion`, but for custom agents (`.claude/agents/*.md`) instead of skills.

(Bucket: Utility — mine, propose, build one custom agent.)

## Steps

### 1. Gather the review window (run this first, no exceptions)

Before looking at anything else — even if the current session is short or feels like there's "nothing to scan" — run these two commands. The reuse signal you're after usually lives in *past* sessions, not the current one.

```bash
~/.claude/skills/lib/find-last-skill-invocation.sh agent-suggestion
```

This prints the ISO-8601 timestamp of agent-suggestion's previous invocation for this project, or nothing if it's never run before. Then resolve which transcripts to mine:

```bash
~/.claude/skills/lib/list-transcripts-since.sh "<cutoff-from-above>"
```

Passing an empty string (first-ever run) lists the full transcript history instead. Do not proceed to step 2 until both commands have actually been run and you have the resulting file list in hand.

### 2. Scan for Agent-tool spawn patterns

Review this session's own `Agent` tool_use calls, **plus** every transcript listed in step 1 (never read a transcript whole — these files are large by design; `grep` for `"name":"Agent"` entries and pull the surrounding `subagent_type`, `description`, and `prompt` fields).

Most candidates show up as `general-purpose`/`Explore` spawns carrying a hand-typed prose brief every time, instead of naming an existing custom agent via `subagent_type`. Group spawns by their underlying **task shape** — not by surface wording. For example: "fetch one URL, extract findings relevant to a topic, report back a distillate" is one shape even when it's spawned repeatedly with completely different URLs and subjects.

### 3. Apply the fit heuristic to each group

A candidate must clear **all three** of these tests to qualify — this is the exact heuristic derived 2026-08-17 from a real audit of 82 `Agent`-tool spawns across 10 sessions, the same analysis that produced the existing `source-reviewer` and `skill-reviewer` agents. It's established precedent, not something to re-derive from scratch each run:

1. **Recurring** — the shape appears across multiple sessions or orchestrators, not a one-off. A single occurrence never qualifies, no matter how clean the shape looks.
2. **Cold-start compatible** — the subtask needs no inherited conversation context. If it depends on context only the parent session has, `fork` is already the right tool for it — that's disqualifying, not a design detail to route around.
3. **Stable/describable** — same tools, same output shape, same model choice every time, currently being re-typed as prose per call instead of reused.

Rank every group that clears all three, most valuable (most frequent / most friction-reducing) first. Drop any group that fails even one test, however frequent it is.

### 4. Propose them

Present each qualifying candidate to the user, concisely, most valuable first:

- **Agent name** (kebab-case) and a one-sentence job.
- **Minimal tool list** it actually needs (e.g. `Read, Grep, Glob, Bash` for a read-only miner; `WebFetch, WebSearch` for a source-review-style fetcher) — never inherit-all by default.
- **Model choice** — `haiku` only for pure mechanical extraction with zero judgment calls (mirror `source-reviewer`); omit `model:` for anything judgment-bearing, like auditing or synthesis (mirror `skill-reviewer`).
- **The exact call site(s)** (skill name + step) that would switch from a hand-typed prose brief to `subagent_type: "<name>"` — name the real skill and step, not a hypothetical one.

Use the **AskUserQuestion** tool (multi-select if there's more than one candidate) with options **Build it as proposed**, **Let me tweak it first** (gather the requested changes, then proceed), and **Skip it**. Don't ask this in free-form prose.

If nothing in the conversation or logs clears the bar, say so plainly and stop — do not invent a candidate just to have one.

### 5. Build them

For each candidate on **Build it as proposed** (or after applying the user's tweaks):

1. Write `dotfiles/bosko/claude/agents/<name>.md` with proper frontmatter (`name`, `description`, `tools`, `model` if warranted, `color`) and a system-prompt body following the existing agents' conventions: resolve its own scope if none was handed to it, stay read-only unless the task genuinely requires otherwise, define a concrete report format, end with a one-line tally instruction, and add a `Gotchas` section only if seeded by a known failure mode (not speculative).
2. Add its `.claude/agents/<name>.md` entry to `dotfiles/bosko/bosko-claude.nix`'s `home.file` block — mirror any existing agent entry's pattern exactly (`source = "${self}/dotfiles/bosko/claude/agents/<name>.md"; force = true;`). Don't cite a specific entry count in this instruction — it keeps drifting upward as agents are added (three at this skill's own creation, four as of 2026-09-04).
3. Actually edit the call site(s) named in step 4 to spawn `subagent_type: "<name>"` instead of the old prose brief. This handoff is the real payoff — don't stop at just writing the agent file.

### 6. Confirm + certify

Report what was built: the agent name, where it was written, and which call site(s) were switched over (skill + step). This is a repo-managed change (a new agent file, nix wiring, and at least one edited skill) — remind the user:

- Run the `nixos-dry-run` skill to confirm the flake still evaluates.
- It only reaches `~/.claude` after `nh os boot /home/bosko/NixOS` **and a reboot** — the repo copy works in the meantime when invoked from within this repo. No new session is needed beyond that once rebuilt.

## Gotchas

- **`find-last-skill-invocation.sh` misses slash-command invocations.** It only greps for
  assistant-initiated `Skill` tool_use entries — when this skill is run the normal way, via a
  user-typed `/agent-suggestion`, Claude Code injects the instructions as user-turn content
  instead, so the detector never records it. `skill-suggestion` and `skill-audit` hit the
  identical blind spot with their own equivalent Step 1. If the reported cutoff looks
  suspiciously old given known recent activity, cross-check
  `git log --oneline | grep -i 'agent-suggestion\|custom agent' | head -1` (or any other
  agent-suggestion-specific commit marker) as a sanity check before trusting it.
- **An invocation attempt that *errors out* (e.g. "Unknown skill" before a rebuild lands) still
  gets logged as a real `Skill` tool_use and counts toward `find-last-skill-invocation.sh`'s
  cutoff.** Hit for real 2026-08-18: a pre-rebuild smoke-test attempt failed outright, did zero
  scanning, yet the very next real run picked its timestamp up as "the previous invocation,"
  narrowing the window to just the current session (which had no `Agent`-tool spawns of its
  own) — nearly causing a false "nothing to scan" verdict on this skill's actual first
  productive run. If the reported cutoff lands inside the *current* session and no completed
  pass (proposal made, or explicit "nothing qualifies" verdict) is visible at that timestamp,
  treat it as a failed/incomplete attempt and widen to the full history for that run instead.
- **Two ad hoc tool misfires during log-mining (observed 2026-09-04/05):** a hand-typed
  `tail -+201` on a misfire-scan pipe failed with `tail: invalid option -- '+'` — GNU tail wants
  `tail -n +201`, not `tail -+201`. Separately, a `ScheduleWakeup` call used as a fallback
  heartbeat while waiting on several `Agent`-tool sub-agent spawns failed with `` `prompt` is
  required when `stop` is not true`` — `ScheduleWakeup` always needs `prompt` (and
  `delaySeconds`/`reason`) even when it's just a heartbeat, and per `research`'s own Gotchas,
  work spawned via the `Agent` tool doesn't need polling at all: the harness delivers a
  completion notification automatically, so just let the turn end after spawning.
