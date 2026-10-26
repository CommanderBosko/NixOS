#!/usr/bin/env bash
# diagnose-hung-game.sh — fixed diagnostic command battery for a hung/frozen/crashed
# Steam/Proton game on the gaming host. Runs the judgment-free part of the runbook
# (SKILL.md step 1's battery, plus the --sentry/--proton-chain/--ue-logs modes below)
# and prints raw output for interpretation.
#
# The battery's own sections are numbered [N/7] to keep them distinct from SKILL.md's
# step numbers.
#
# What it does NOT do:
#   - Battery [6/7] (sudo dmesg, SKILL.md step 3) — can't run non-interactively; prints
#     the command to run manually.
#
# Usage:
#   diagnose-hung-game.sh <game-grep-pattern> [pid]
#     <game-grep-pattern>  extended-regex pattern matching the game's process name(s),
#                          e.g. "wardogs|war_dogs|war dogs"
#     [pid]                optional: skip auto-detection and inspect this PID directly
#
#   diagnose-hung-game.sh --sentry <game-dir>
#     Locates the game's Sentry crash-handler DB, if any (SKILL.md step 4).
#
#   diagnose-hung-game.sh --proton-chain <crash-time> [game-name]
#     Checks the Steam/Proton/reaper/crashpad process chain and journal/coredump
#     history around the crash time (SKILL.md step 5). <crash-time> is any string
#     `journalctl --since` accepts (e.g. "2026-09-16 14:30"). [game-name] narrows the
#     journal grep to that title as well as the fixed crash-keyword set.
#
#   diagnose-hung-game.sh --ue-logs <game-dir> <appid> [game-name]
#     Searches the Unreal Engine Saved/Logs locations (SKILL.md step 6).

set -uo pipefail

MODE="${1:-}"

case "$MODE" in
  --sentry)
    GAME_DIR="${2:-}"
    if [[ -z "$GAME_DIR" ]]; then
      echo "Usage: $0 --sentry <game-dir>" >&2
      exit 1
    fi
    echo "=== Sentry crash-handler DB ==="
    find "$GAME_DIR/.sentry-native" -maxdepth 2 2>&1
    echo
    echo "=== If a run/report dir was found above, list it for timestamps ==="
    find "$GAME_DIR/.sentry-native" -maxdepth 2 \( -name "*.run" -o -name "reports" \) -exec ls -la --time-style=full-iso {} \; 2>&1
    exit 0
    ;;
  --proton-chain)
    CRASH_TIME="${2:-}"
    GAME_NAME="${3:-}"
    if [[ -z "$CRASH_TIME" ]]; then
      echo "Usage: $0 --proton-chain <crash-time> [game-name]" >&2
      exit 1
    fi
    JOURNAL_PATTERN="segfault|oom|killed process|core.?dump|out of memory|signal|proton"
    if [[ -n "$GAME_NAME" ]]; then
      JOURNAL_PATTERN="${JOURNAL_PATTERN}|${GAME_NAME}"
    fi
    echo "=== Steam/Proton/reaper/crashpad process chain ==="
    # Drop noise that matches the keywords but is never part of the chain:
    #   - grep itself and this script's own invocation line (its command line holds
    #     "diagnose-hung-game.sh --proton-chain", which self-matches "proton");
    #   - kernel threads (ps aux shows their command as "[name]" in column 11), e.g.
    #     "[oom_reaper]" and the many "[kworker/N:M-wg-crypt-proton0]" WireGuard workers.
    ps aux | grep -i -E "reaper|proton|steam.exe|steamwebhelper|SteamLaunch|start_protected_game|crashpad" \
      | grep -v -E "grep|diagnose-hung-game\.sh" | awk '$11 !~ /^\[/'
    echo
    echo "=== Journal since $CRASH_TIME ==="
    journalctl --since "$CRASH_TIME" 2>&1 | grep -i -E "$JOURNAL_PATTERN"
    echo
    echo "=== Coredumps since $CRASH_TIME ==="
    coredumpctl list --since "$CRASH_TIME" 2>&1
    exit 0
    ;;
  --ue-logs)
    GAME_DIR="${2:-}"
    APPID="${3:-}"
    GAME_NAME="${4:-}"
    if [[ -z "$GAME_DIR" || -z "$APPID" ]]; then
      echo "Usage: $0 --ue-logs <game-dir> <appid> [game-name]" >&2
      exit 1
    fi
    echo "=== Saved/Logs under the game's own install dir ==="
    find "$GAME_DIR/Saved/Logs" -maxdepth 1 2>&1
    echo
    echo "=== Any 'Saved' dir under the game's install tree ==="
    find "$GAME_DIR" -iname "Saved" 2>&1
    echo
    echo "=== Log files under the Proton compatdata prefix ==="
    PAT="saved"
    if [[ -n "$GAME_NAME" ]]; then
      PAT="${PAT}|${GAME_NAME}"
    fi
    find "/home/bosko/.local/share/Steam/steamapps/compatdata/$APPID" -iname "*.log" 2>&1 | grep -i -E "$PAT"
    exit 0
    ;;
esac

PATTERN="${1:-}"
PID_OVERRIDE="${2:-}"

if [[ -z "$PATTERN" ]]; then
  echo "Usage: $0 <game-grep-pattern> [pid]" >&2
  echo "       $0 --sentry <game-dir>" >&2
  echo "       $0 --proton-chain <crash-time> [game-name]" >&2
  echo "       $0 --ue-logs <game-dir> <appid> [game-name]" >&2
  echo "Example: $0 \"wardogs|war_dogs|war dogs\"" >&2
  exit 1
fi

echo "=== [1/7] Host / uptime ==="
hostname && echo "---" && uptime
echo

echo "=== [2/7] Matching processes (pattern: $PATTERN) ==="
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

echo "=== [3/7] GPU state (nvidia-smi) ==="
nvidia-smi 2>&1 | head -50
echo

echo "=== [4/7] Memory / load pressure ==="
free -h && echo "---" && cat /proc/loadavg
echo

if [[ -n "${PID:-}" ]]; then
  echo "=== [5/7] Per-thread state for PID $PID ==="
  nproc && echo "---STATUS---" && cat "/proc/$PID/status" 2>&1 | head -20
  echo "---WCHAN---"
  cat "/proc/$PID/wchan" 2>&1; echo
  echo "---THREADS (top10 by cpu)---"
  ps -L -p "$PID" -o pid,tid,pcpu,stat,wchan:32,comm --sort=-pcpu 2>&1 | head -15
else
  echo "=== [5/7] Per-thread state ==="
  echo "No PID found or given for pattern '$PATTERN' — process may have already exited. Skipping."
fi
echo

echo "=== [6/7] Kernel dmesg — requires sudo, run manually and paste output back ==="
echo 'sudo dmesg -T 2>&1 | tail -80'
echo

echo "=== [7/7] Kernel journal — nvidia/xid/hung/oom/error/fault/reset, last hour ==="
journalctl -k --since "1 hour ago" 2>&1 | grep -i -E "nvidia|xid|hung|nmi|oom|error|fault|reset" | tail -60
echo

echo "=== Done: battery [1/7]-[7/7] complete. Run the [6/7] dmesg command manually (SKILL.md step 3), then continue with SKILL.md steps 4-6 for crash-log locations. ==="
