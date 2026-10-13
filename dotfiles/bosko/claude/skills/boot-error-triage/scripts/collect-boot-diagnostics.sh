#!/usr/bin/env bash
# Usage:
#   collect-boot-diagnostics.sh         — journal sections drop known-benign noise (see NOISE_PATTERNS)
#   collect-boot-diagnostics.sh --raw   — journal sections unfiltered
set -euo pipefail

# Known-benign boot-log noise, one extended regex per line. The journal sections drop
# matching lines and print a per-pattern count instead, so nothing disappears silently.
# - dbus-broker duplicate names: several portal/keyring packages ship the same D-Bus service name.
# - gkr-pam: the display manager's PAM stack looks for gnome-keyring's control file before it exists.
NOISE_PATTERNS=(
  'dbus-broker-launch.*Ignoring duplicate name'
  'gkr-pam: unable to locate daemon control file'
)

RAW=false
case "${1:-}" in
  "") ;;
  --raw) RAW=true ;;
  *)
    echo "usage: collect-boot-diagnostics.sh [--raw]" >&2
    exit 2
    ;;
esac

# Print the journal at the given priority, minus NOISE_PATTERNS (unless --raw).
journal_section() {
  local prio="$1" out pat count filtered=false
  out="$(journalctl -b -p "$prio" --no-pager 2>&1 || true)"
  if [ "$RAW" = true ]; then
    printf '%s\n' "$out"
    return
  fi
  local args=()
  for pat in "${NOISE_PATTERNS[@]}"; do
    args+=(-e "$pat")
  done
  printf '%s\n' "$out" | grep -v -E "${args[@]}" || true
  for pat in "${NOISE_PATTERNS[@]}"; do
    count="$(printf '%s\n' "$out" | grep -c -E -e "$pat" || true)"
    if [ "$count" -gt 0 ]; then
      if [ "$filtered" = false ]; then
        echo "--- filtered as known noise (rerun with --raw to see them) ---"
        filtered=true
      fi
      printf '%s lines: %s\n' "$count" "$pat"
    fi
  done
}

echo "=== Failed units ==="
systemctl --failed --no-legend || true

echo
echo "=== Boot timing ==="
systemd-analyze 2>&1 || true

echo
echo "=== Journal: priority <= 3 (error+), current boot ==="
journal_section 3

echo
echo "=== Journal: priority <= 2 (crit+), current boot ==="
journal_section 2

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
