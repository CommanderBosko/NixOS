#!/usr/bin/env bash
# diagnose-hung-game.sh — fixed diagnostic command battery for a hung/frozen/crashed
# Steam/Proton game on the gaming host. Runs the judgment-free part of the runbook
# (steps 1-5 and 7) and prints raw output for interpretation.
#
# What it does NOT do:
#   - Step 6 (sudo dmesg) — can't run non-interactively; prints the command to run manually.
#   - Steps 8-10 (Sentry DB, Steam/Proton process chain, engine-specific log paths) — these
#     vary per game/engine and require judgment; see SKILL.md.
#
# Usage: diagnose-hung-game.sh <game-grep-pattern> [pid]
#   <game-grep-pattern>  extended-regex pattern matching the game's process name(s),
#                        e.g. "wardogs|war_dogs|war dogs"
#   [pid]                optional: skip auto-detection and inspect this PID directly

set -uo pipefail

PATTERN="${1:-}"
PID_OVERRIDE="${2:-}"

if [[ -z "$PATTERN" ]]; then
  echo "Usage: $0 <game-grep-pattern> [pid]" >&2
  echo "Example: $0 \"wardogs|war_dogs|war dogs\"" >&2
  exit 1
fi

echo "=== 1. Host / uptime ==="
hostname && echo "---" && uptime
echo

echo "=== 2. Matching processes (pattern: $PATTERN) ==="
# Exclude grep noise and this script's own invocation line (the wrapping shell/bash
# process's command line contains this script's path + the literal pattern argument,
# so it self-matches almost any pattern when no real game process is running).
ps aux | grep -i -E "$PATTERN" | grep -v -E "grep|diagnose-hung-game\.sh"
echo

if [[ -n "$PID_OVERRIDE" ]]; then
  PID="$PID_OVERRIDE"
else
  PID=$(ps aux | grep -i -E "$PATTERN" | grep -v -E "grep|diagnose-hung-game\.sh" | awk '{print $2}' | head -1)
fi

echo "=== 3. GPU state (nvidia-smi) ==="
nvidia-smi 2>&1 | head -50
echo

echo "=== 4. Memory / load pressure ==="
free -h && echo "---" && cat /proc/loadavg
echo

if [[ -n "${PID:-}" ]]; then
  echo "=== 5. Per-thread state for PID $PID ==="
  nproc && echo "---STATUS---" && cat "/proc/$PID/status" 2>&1 | head -20
  echo "---WCHAN---"
  cat "/proc/$PID/wchan" 2>&1; echo
  echo "---THREADS (top10 by cpu)---"
  ps -L -p "$PID" -o pid,tid,pcpu,stat,wchan:32,comm --sort=-pcpu 2>&1 | head -15
else
  echo "=== 5. Per-thread state ==="
  echo "No PID found or given for pattern '$PATTERN' — process may have already exited. Skipping."
fi
echo

echo "=== 6. Kernel dmesg — requires sudo, run manually and paste output back ==="
echo 'sudo dmesg -T 2>&1 | tail -80'
echo

echo "=== 7. Kernel journal — nvidia/xid/hung/oom/error/fault/reset, last hour ==="
journalctl -k --since "1 hour ago" 2>&1 | grep -i -E "nvidia|xid|hung|nmi|oom|error|fault|reset" | tail -60
echo

echo "=== Done: steps 1-5 and 7 complete. Run step 6 manually, then continue with SKILL.md steps 8-10 for crash-log locations. ==="
