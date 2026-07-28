#!/usr/bin/env bash
set -euo pipefail

echo "=== Failed units ==="
systemctl --failed --no-legend || true

echo
echo "=== Boot timing ==="
systemd-analyze 2>&1 || true

echo
echo "=== Journal: priority <= 3 (error+), current boot ==="
journalctl -b -p 3 --no-pager || true

echo
echo "=== Journal: priority <= 2 (crit+), current boot ==="
journalctl -b -p 2 --no-pager || true

echo
echo "=== CPU ==="
lscpu | grep -E "Model name|Vendor|Family" || true

echo
echo "=== Kernel ==="
uname -r
echo
cat /proc/cmdline

echo
echo "=== Board / BIOS identity ==="
for f in board_vendor board_name bios_vendor bios_version bios_date; do
  path="/sys/class/dmi/id/$f"
  if [ -r "$path" ]; then
    printf '%s: %s\n' "$f" "$(cat "$path")"
  fi
done
