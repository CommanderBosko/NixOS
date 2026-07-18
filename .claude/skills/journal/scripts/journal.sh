#!/usr/bin/env bash
#
# journal.sh — Fetch the last 50 lines of journald output for a service,
# locally or on a remote host.
#
# Usage:
#   journal.sh <service> [host]
#
# With no host, runs journalctl locally. With a host, resolves its SSH
# target via .claude/lib/resolve-host.sh (never hardcode a copy of that
# lookup) and runs journalctl there with a 30s timeout.
#
# On host-resolution failure, prints the host table from resolve-host.sh
# and exits 1 so the caller can fall back to AskUserQuestion.

set -uo pipefail

SERVICE="${1:?usage: journal.sh <service> [host]}"
HOST="${2:-}"

if [ -z "$HOST" ]; then
  journalctl -u "$SERVICE" -n 50 --no-pager
  exit $?
fi

TARGET="$(bash /home/bosko/NixOS/.claude/lib/resolve-host.sh "$HOST")"
STATUS=$?

if [ "$STATUS" -ne 0 ]; then
  echo "$TARGET"
  exit 1
fi

timeout 30 ssh "$TARGET" "journalctl -u '$SERVICE' -n 50 --no-pager"
