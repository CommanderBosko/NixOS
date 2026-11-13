#!/usr/bin/env bash
# Usage: health-scan.sh
# Read-only health scan of the CURRENT host. Prints labelled sections; never exits non-zero
# for a finding (interpretation is the caller's job). Uses `sudo -n` only for smartctl.
set -uo pipefail

section() { printf '\n=== %s ===\n' "$1"; }
have() { command -v "$1" >/dev/null 2>&1; }

section "Host"
echo "$(hostname) | $(nixos-version 2>/dev/null || echo 'not NixOS') | kernel $(uname -r)"
uptime -p 2>/dev/null || true

section "Failed units (system + user)"
systemctl --failed --no-legend || true
systemctl --user --failed --no-legend 2>/dev/null || true
echo "system state: $(systemctl is-system-running 2>&1 || true)"

section "Disk (/ and /boot)"
df -h / /boot 2>/dev/null || true

section "Memory, load, pressure"
free -h
cat /proc/loadavg
for f in cpu memory io; do
  printf 'PSI %s: ' "$f"
  head -1 "/proc/pressure/$f" 2>/dev/null || echo n/a
done

section "System generations"
ls -d /nix/var/nix/profiles/system-*-link 2>/dev/null | wc -l

section "smartd"
echo "smartd: $(systemctl is-active smartd 2>&1 || true)"

section "NVMe/SMART"
if have smartctl; then
  scan="$(sudo -n smartctl --scan 2>&1 || true)"
  echo "$scan"
  # --scan reports /dev/nvme0 (not nvme0n1); `-d <type>` is part of each line
  printf '%s\n' "$scan" | awk '/^\/dev\//{print $1}' | while read -r dev; do
    echo "--- $dev ---"
    sudo -n smartctl -H -A "$dev" 2>&1 \
      | grep -E -i 'overall-health|SMART Health Status|Critical Warning|Temperature:|Available Spare|Percentage Used|Data Units|Power Cycles|Power On Hours|Unsafe Shutdowns|Media and Data|Error Information|permission|password|not permitted|sudo' \
      || echo "(no SMART output — sudo -n likely denied; run: ! sudo smartctl -H -A $dev)"
  done
else
  echo "smartctl not installed"
fi

section "Battery"
bat="$(have upower && upower -e 2>/dev/null | grep -i bat | head -1 || true)"
if [ -n "$bat" ]; then
  upower -i "$bat" | grep -E -i 'state|energy-full:|energy-full-design|charge-cycles|percentage|capacity|energy-rate'
  for t in /sys/class/power_supply/BAT*/charge_control_end_threshold; do
    [ -r "$t" ] && echo "charge_control_end_threshold: $(cat "$t")"
  done
else
  echo "no battery (desktop) — skipped"
fi

section "Temperatures"
if have sensors; then sensors 2>/dev/null | grep -E -i 'package|composite|Tctl|Tdie|edge|junction|fan' || true; else echo "sensors not installed"; fi

section "Boot journal (noise-filtered, via boot-error-triage)"
# Prefer the sibling copy so both skills come from the same generation (the installed
# ~/.claude copy can lag the repo until a rebuild).
collector="$(dirname "$0")/../../boot-error-triage/scripts/collect-boot-diagnostics.sh"
[ -x "$collector" ] || collector="$HOME/.claude/skills/boot-error-triage/scripts/collect-boot-diagnostics.sh"
"$collector" 2>&1 | sed -n '/=== Journal: priority <= 3/,/=== CPU ===/p' | sed '/=== CPU ===/d'
