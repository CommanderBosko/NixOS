# Research — Gotchas

Load this when a sub-agent wait misbehaves or `save-memory` seems unavailable.

- **What went wrong:** Step 5's "wait for all sub-agents to report back" was read as "actively poll for completion," leading to three consecutive malformed `ScheduleWakeup` calls in one session (missing `prompt`, then missing `delaySeconds`/`reason`) before giving up on it.
- **How to avoid it:** don't call `ScheduleWakeup` to wait on sub-agents spawned via the `Agent` tool — that work is harness-tracked, so a completion notification arrives automatically as a later turn without any polling call. Just let the turn end after spawning; there is nothing to schedule.
- **`save-memory` isn't guaranteed available in every project** — it's global/repo-managed (auto-symlinked into `~/.claude/skills/save-memory` by `claude-hm/files.nix`, from `dotfiles/bosko/claude/skills/save-memory`), the same mechanism as `research` itself, not a project-local skill. But a repo-managed skill only reaches `~/.claude` after a rebuild, so on a machine that hasn't rebuilt since it was added (or a non-Home-Manager machine) it may still be missing. Step 7 must check the available-skills list before invoking it, not assume it exists just because `research` does.
