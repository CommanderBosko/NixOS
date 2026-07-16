#!/usr/bin/env bash
# Mechanical health-check battery for a single systemd service.
# Usage: verify-service.sh <unit> [mount-path] [data-dir] [port-pattern]
# port-pattern defaults to the unit name; pass a known port (e.g. "8096")
# too when the process name doesn't appear in `ss` output verbatim.
# Runs locally — for a remote host, the skill prefixes this whole invocation
# with the resolved SSH command itself; this script has no host logic.
set -uo pipefail

UNIT="${1:?usage: verify-service.sh <unit> [mount-path] [data-dir] [port-pattern]}"
MOUNT="${2:-}"
DATADIR="${3:-}"
PORT_PATTERN="${4:-$UNIT}"

echo "--- service ---"
systemctl is-active "$UNIT"
systemctl status "$UNIT" --no-pager -n 5 2>&1

echo "--- ports (tcp) ---"
ss -tlnp 2>/dev/null | grep -E "$PORT_PATTERN" || echo "(no tcp match for '$PORT_PATTERN')"
echo "--- ports (udp) ---"
ss -ulnp 2>/dev/null | grep -E "$PORT_PATTERN" || echo "(no udp match for '$PORT_PATTERN')"

if [ -n "$MOUNT" ]; then
  echo "--- mount ---"
  findmnt "$MOUNT" 2>&1
fi

if [ -n "$DATADIR" ]; then
  echo "--- data dir ---"
  ls -ld "$DATADIR" "$DATADIR"/* 2>&1
fi
