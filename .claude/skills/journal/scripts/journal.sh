#!/usr/bin/env bash
#
# journal.sh — Fetch journald output for a service, locally or on a remote
# host. Default: the last 50 lines.
#
# Usage:
#   journal.sh <service> [host] [-n N] [-f [--for SECONDS]]
#
#   <service>        journald unit / service name (required)
#   [host]           host from .claude/hosts.json; omit for the local box
#   -n, --lines N    show the last N lines instead of 50
#   -f, --follow     follow new entries live (after the last N lines). Stops
#                    on its own after a bounded window so it can't hang the
#                    caller: 60s by default, or --for SECONDS.
#
# Options may come before or after the positional args, so the original
# `journal.sh <service> [host]` form is unchanged.
#
# With no host, runs journalctl locally. With a host, resolves its SSH
# target via .claude/lib/resolve-host.sh (never hardcode a copy of that
# lookup) and runs journalctl there with a 30s timeout (follow mode: the
# window plus 15s, and the remote journalctl is bounded by the window too).
#
# On host-resolution failure, prints the host table from resolve-host.sh
# and exits 1 so the caller can fall back to AskUserQuestion.
# Exit: journalctl's/ssh's status | 1 unknown host | 2 usage error.
# A follow window that runs out normally exits 0.

set -uo pipefail

usage() {
  echo "usage: journal.sh <service> [host] [-n N] [-f [--for SECONDS]]" >&2
  exit 2
}

LINES_N=50
FOLLOW=0
FOLLOW_SECS=60
POS=()

while [ $# -gt 0 ]; do
  case "$1" in
    -n|--lines) LINES_N="${2:-}"; shift 2 2>/dev/null || usage ;;
    -f|--follow) FOLLOW=1; shift ;;
    --for) FOLLOW_SECS="${2:-}"; shift 2 2>/dev/null || usage ;;
    -h|--help) usage ;;
    -*) echo "journal.sh: unknown option: $1" >&2; usage ;;
    *) POS+=("$1"); shift ;;
  esac
done

case "$LINES_N" in ''|*[!0-9]*) echo "journal.sh: -n needs a whole number" >&2; usage ;; esac
case "$FOLLOW_SECS" in ''|*[!0-9]*|0) echo "journal.sh: --for needs a positive whole number of seconds" >&2; usage ;; esac
[ "${#POS[@]}" -ge 1 ] && [ "${#POS[@]}" -le 2 ] || usage

SERVICE="${POS[0]}"
HOST="${POS[1]:-}"

JCMD=(journalctl -u "$SERVICE" -n "$LINES_N" --no-pager)
TIMEOUT=30
if [ "$FOLLOW" -eq 1 ]; then
  JCMD=(timeout "$FOLLOW_SECS" "${JCMD[@]}" -f)
  TIMEOUT=$((FOLLOW_SECS + 15))
fi

# `timeout` exits 124 when the follow window runs out — that's the normal end.
finish() {
  local status="$1"
  if [ "$FOLLOW" -eq 1 ] && [ "$status" -eq 124 ]; then
    echo "-- follow window of ${FOLLOW_SECS}s ended --" >&2
    exit 0
  fi
  exit "$status"
}

if [ -z "$HOST" ]; then
  "${JCMD[@]}"
  finish $?
fi

TARGET="$(bash /home/bosko/NixOS/.claude/lib/resolve-host.sh "$HOST")"
STATUS=$?

if [ "$STATUS" -ne 0 ]; then
  echo "$TARGET"
  exit 1
fi

timeout "$TIMEOUT" ssh "$TARGET" "$(printf '%q ' "${JCMD[@]}")"
finish $?
