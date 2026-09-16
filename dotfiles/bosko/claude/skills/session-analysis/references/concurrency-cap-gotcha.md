# Concurrency Cap Gotcha

Load this before fanning out `transcript-scanner` across multiple projects in a single message.

- **The per-project 10-15 file batch cap doesn't bound the *total* fan-out across every
  project in one pass.** Hit for real: spawning a `transcript-scanner` wave across multiple
  projects in a single message exceeded the harness's 20-concurrent-subagent cap
  ("Concurrent subagent limit reached... do not retry"), and the recovery attempt made it
  worse — a standalone `sleep 30` to wait out the capacity is itself blocked by the harness
  (use `Monitor` with an until-loop, or just let the turn end and rely on the completion
  notification, per `research`'s Gotchas — never a bare `sleep`). Cap total concurrent spawns
  per message at ≤20 across *all* projects combined, not just per project — split into
  multiple waves (spawn a batch, let it complete, spawn the next) if the full manifest needs
  more than that.
