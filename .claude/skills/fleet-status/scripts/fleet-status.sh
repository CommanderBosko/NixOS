#!/usr/bin/env bash
# fleet-status.sh — read-only health sweep across all NixOS hosts.
# For each host: current generation, NixOS version, failed units, uptime,
# and whether a reboot is pending (booted vs current system differ).
# Then WireGuard handshake freshness, read from vpn-server (passwordless sudo).
# Safe: read-only. No sudo on the desktops (all probes are unprivileged).
set -uo pipefail

HOSTS=("gaming" "laptop" "natalie-laptop" "vpn-server")
declare -A SSH_TARGET=(
  [gaming]="bosko@gaming"
  [laptop]="bosko@laptop"
  [natalie-laptop]="bosko@natalie-laptop"
  [vpn-server]="bosko@150.136.232.63"
)
SELF="$(hostname)"

# Unprivileged probe run on each host; emits one pipe-delimited line.
# "staged=YES" means the latest built generation isn't the running one — a rebuild was
# staged (e.g. via `nh os boot`) but not yet activated/rebooted.
probe() {
  cat <<'REMOTE'
gen=$(readlink /nix/var/nix/profiles/system 2>/dev/null | sed 's/.*system-//;s/-link//')
ver=$(nixos-version 2>/dev/null)
failed=$(systemctl --failed --no-legend --plain 2>/dev/null | awk '{print $1}' | paste -sd, -)
secs=$(cut -d. -f1 /proc/uptime 2>/dev/null); secs=${secs:-0}
up="$((secs/86400))d $(((secs%86400)/3600))h $(((secs%3600)/60))m"
if [ "$(readlink -f /run/current-system 2>/dev/null)" = "$(readlink -f /nix/var/nix/profiles/system 2>/dev/null)" ]; then
  staged=no
else
  staged=YES
fi
echo "gen=${gen:-?}|ver=${ver:-?}|failed=${failed:-none}|up=${up}|staged=${staged}"
REMOTE
}

echo "==> NixOS fleet status — $(date '+%Y-%m-%d %H:%M:%S')"
for h in "${HOSTS[@]}"; do
  if [ "$h" = "$SELF" ]; then
    out=$(bash -c "$(probe)" 2>/dev/null)
  else
    out=$(ssh -o BatchMode=yes -o ConnectTimeout=8 -o StrictHostKeyChecking=accept-new \
          "${SSH_TARGET[$h]}" "bash -s" <<<"$(probe)" 2>/dev/null)
  fi
  if [ -z "${out:-}" ]; then
    printf '  %-16s UNREACHABLE\n' "$h"
  else
    printf '  %-16s %s\n' "$h" "$out"
  fi
done

echo
echo "==> WireGuard handshakes (from vpn-server)"
ssh -o BatchMode=yes -o ConnectTimeout=8 bosko@150.136.232.63 '
  now=$(date +%s)
  sudo wg show wg0 latest-handshakes 2>/dev/null | while read -r peer hs; do
    case "$peer" in
      M9KajsVX9wKLyeqz8F4kXbtelJYxYZP2b+cvkYMZ+nA=) n=gaming ;;
      c4H2dY7dGuvanWpmpChT4vocjDPB+pbC8KeLJ2N8m3s=) n=laptop ;;
      YRrCAJ44V1y9uVkt7NWk8w61TDlU4o1G0MDLH0GSpSE=) n=natalie-laptop ;;
      *) n="$peer" ;;
    esac
    if [ "${hs:-0}" -gt 0 ]; then
      printf "  %-16s %ss ago\n" "$n" "$((now - hs))"
    else
      printf "  %-16s never\n" "$n"
    fi
  done
' 2>/dev/null || echo "  vpn-server unreachable"
