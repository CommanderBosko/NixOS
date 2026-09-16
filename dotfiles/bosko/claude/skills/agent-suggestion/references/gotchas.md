# Agent Suggestion — Gotchas

Load this when Step 1's reported cutoff looks suspiciously old, or a raw tool call in this skill's flow misbehaves.

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
