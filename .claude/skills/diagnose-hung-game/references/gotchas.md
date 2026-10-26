# Diagnose Hung Game — Gotchas

Load this before editing the process lookup in `scripts/diagnose-hung-game.sh` (the battery's `[2/7]` section or `--proton-chain`), or if the battery resolves a PID when no game is running.

- **The battery's `ps aux | grep` (its `[2/7] Matching processes` section) used to self-match**
  the wrapping shell's own invocation line (which contains this script's path and the literal
  pattern argument) whenever no real game process was running — silently resolving a bogus
  PID (the shell wrapper) instead of reporting "no match." Fixed by also filtering out any
  line containing `diagnose-hung-game.sh`; confirmed live during `ship-skill`'s smoke test
  (2026-08-25) that a no-match pattern now correctly reports "No PID found" and a real match
  (`kitty`) still resolves normally.

- **`--proton-chain`'s process listing needs the same self-match filter, plus a kernel-thread
  filter.** Its keyword grep (`reaper|proton|…|crashpad`) matches the script's own invocation
  line (`--proton-chain` contains "proton") and, on a host with a WireGuard interface named
  `proton0`, dozens of `[kworker/N:M-wg-crypt-proton0]` / `[napi/proton0-0]` kernel threads
  plus `[oom_reaper]` — about 70 lines of noise where ~26 real chain processes belong. Fixed
  by filtering out lines containing `diagnose-hung-game.sh` and dropping kernel threads
  (`ps aux` shows their command as `[name]` in column 11, so `awk '$11 !~ /^\[/'`). Keep both
  filters if you touch that pipeline; verified 2026-10-25 (100 → 54 lines of output on gaming,
  zero `[…]` or `diagnose-hung-game` lines left).
