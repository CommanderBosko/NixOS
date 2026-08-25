---
name: diagnose-hung-game
description: Run a structured diagnostic runbook when a Steam/Proton game on the gaming host freezes, hangs, or crashes. Use when the user says "game is frozen", "diagnose hung game", "why did X crash", "check game crash logs", "steam game not responding", or "game froze on gaming".
---

# Diagnose a Hung/Crashed Steam Game

Runs the fixed diagnostic battery this project already uses to root-cause a frozen or
crashed Steam/Proton game on the gaming host, then walks the game-specific crash-log
locations that vary by engine. (Bucket: Utility)

## Arguments

Gather from the user (or infer from context) before starting:

- **Game process pattern** — an extended-regex fragment matching the game's process
  name(s) as they'd appear in `ps aux`, e.g. `"wardogs|war_dogs|war dogs"`. Case doesn't
  matter (the script greps case-insensitively).
- **Game install directory** — needed for steps 8-10, e.g.
  `/home/bosko/.local/share/Steam/steamapps/common/<Game>/<Game>`. If unknown, find it
  with `find /home/bosko/.local/share/Steam/steamapps/common -maxdepth 1` and match by name.
- **Roughly when it hung/crashed** — used to scope the journal/coredump lookups in step 9.

## Steps

1. **Run the fixed command battery.** Call the script:
   ```bash
   .claude/skills/diagnose-hung-game/scripts/diagnose-hung-game.sh "<game-pattern>" [pid]
   ```
   This covers, in order: host/uptime, matching processes (and PID resolution), GPU state
   (`nvidia-smi`), memory/load pressure, per-thread status/wchan for the resolved PID, and a
   kernel-journal grep for `nvidia|xid|hung|nmi|oom|error|fault|reset` over the last hour.
   Read the raw output — don't re-derive these commands by hand.

2. **Interpret the battery's output:**
   - **wchan** on the hung thread(s) tells you what it's blocked on (e.g. stuck in a
     futex/semaphore wait vs. actually spinning on CPU — check the top-CPU thread list too).
   - **nvidia-smi** — look for a process still attached to the GPU with no forward progress,
     unusually high memory use, or a driver in a degraded/reset state.
   - **free -h / loadavg** — rule out OOM pressure or runaway load as the trigger.
   - **journalctl -k grep hits** — an `Xid` line means a GPU-side hang/fault (note the Xid
     code); `oom`/`hung` hits point at the kernel OOM-killer or a hung-task watchdog firing.

3. **Kernel dmesg (sudo-gated — hand off to the user, don't run via Bash).** Ask the user to
   run the command the script printed in its step 6 and paste the output back:
   ```bash
   sudo dmesg -T 2>&1 | tail -80
   ```
   Look for the same signal classes as step 2 (Xid, OOM, hardware faults) plus anything
   immediately preceding the freeze timestamp.

4. **Locate the Sentry crash-handler DB** (if the game bundles Sentry — most Unreal/Unity
   titles with third-party crash reporting do):
   ```bash
   find "<game-dir>/.sentry-native" -maxdepth 2
   ```
   If a `.sentry-native/<run-id>.run/` or `.sentry-native/reports/` directory exists, list it
   with `ls -la --time-style=full-iso` and compare its timestamps against when the game
   froze — a report written right around the hang time is a strong signal of a caught crash
   (vs. a hard hang with no crash handler ever firing).

5. **Check the Steam/Proton/reaper/crashpad process chain and journal around the crash
   time:**
   ```bash
   ps aux | grep -i -E "reaper|proton|steam.exe|steamwebhelper|SteamLaunch|start_protected_game|crashpad" | grep -v grep
   journalctl --since "<approx-crash-time>" 2>&1 | grep -i -E "segfault|oom|killed process|core.?dump|out of memory|signal|<game-name>|proton"
   coredumpctl list --since "<approx-crash-time>"
   ```
   A live `reaper`/`crashpad` process with the game itself gone usually means Proton's
   wrapper caught the exit; a segfault/coredump hit pinpoints a hard crash vs. a silent hang.

6. **If it's an Unreal Engine game, locate `Saved/Logs`** — UE scatters these in either the
   game's own install dir or the Proton compatdata prefix depending on version, so check
   both:
   ```bash
   find "<game-dir>/Saved/Logs" -maxdepth 1 2>&1
   find "<game-dir>" -iname "Saved" 2>&1
   find "/home/bosko/.local/share/Steam/steamapps/compatdata/<appid>" -iname "*.log" 2>&1 | grep -i -E "<game-name>|saved"
   ```
   If neither location has a `Saved/Logs`, note that explicitly rather than assuming the
   game doesn't log — some titles log under the compatdata `AppData` tree instead; widen the
   `find` to the whole compatdata prefix if the first two searches come up empty.

7. **Report back to the user:**
   - Whether the process was still alive/hung vs. already exited when checked.
   - The most likely cause class (GPU hang/Xid, OOM kill, hard segfault/crash, or
     indeterminate) with the specific evidence line(s) that support it.
   - Any crash-report or log file paths found (Sentry report, UE `Saved/Logs`, coredump)
     worth the user opening directly.
   - If nothing conclusive turned up, say so plainly rather than guessing — recommend a
     next capture (e.g. re-run `dmesg`/journal checks immediately after the next hang,
     before logs rotate).

## Scripts

- `.claude/skills/diagnose-hung-game/scripts/diagnose-hung-game.sh <game-pattern> [pid]` —
  runs the fixed, judgment-free command battery (steps 1-5 and 7 above): host/uptime,
  process lookup + PID resolution, `nvidia-smi`, memory/load, per-thread
  status/wchan/top-CPU-threads, and the kernel-journal grep. Prints the sudo `dmesg`
  command as a suggested manual step rather than running it. Called by Step 1.

## Gotchas

- **Step 3 (dmesg) needs sudo** and this repo has no NOPASSWD for the gaming host — always
  hand it to the user to run and paste back, never attempt it via Bash.
- The PID the script resolves is just the **first** match for the given pattern — if a game
  spawns multiple matching processes (e.g. a launcher plus the actual game binary), pass the
  correct PID explicitly as the script's second argument once you've seen step 2's output.
- Game install paths and engine (Unreal vs. other) vary per title — don't assume the
  `Saved/Logs` layout from one game carries over to the next; verify live with `find` rather
  than guessing a path from memory.
- **Step 2's `ps aux | grep` used to self-match** the wrapping shell's own invocation line
  (which contains this script's path and the literal pattern argument) whenever no real game
  process was running — silently resolving a bogus PID (the shell wrapper) instead of
  reporting "no match." Fixed by also filtering out any line containing
  `diagnose-hung-game.sh`; confirmed live during `ship-skill`'s smoke test (2026-08-25) that a
  no-match pattern now correctly reports "No PID found" and a real match (`kitty`) still
  resolves normally.
