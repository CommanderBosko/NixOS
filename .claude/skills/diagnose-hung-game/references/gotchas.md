# Diagnose Hung Game — Gotchas

Load this before editing the process lookup in `scripts/diagnose-hung-game.sh`, or if the battery resolves a PID when no game is running.

- **The battery's `ps aux | grep` (its "2. Matching processes" section) used to self-match**
  the wrapping shell's own invocation line (which contains this script's path and the literal
  pattern argument) whenever no real game process was running — silently resolving a bogus
  PID (the shell wrapper) instead of reporting "no match." Fixed by also filtering out any
  line containing `diagnose-hung-game.sh`; confirmed live during `ship-skill`'s smoke test
  (2026-08-25) that a no-match pattern now correctly reports "No PID found" and a real match
  (`kitty`) still resolves normally.
