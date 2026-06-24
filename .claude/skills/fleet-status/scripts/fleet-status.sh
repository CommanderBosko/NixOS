#!/usr/bin/env bash
# fleet-status.sh — read-only health sweep across all NixOS hosts.
# For each host: current generation, NixOS version, failed units, uptime,
# and whether a reboot is pending (booted vs current system differ).
# Then WireGuard handshake freshness, read from vpn-server (passwordless sudo).
# Safe: read-only. No sudo on the desktops (all probes are unprivileged).
#
# Host list, SSH targets, and the WG peer->host map are read from the single
# source of truth at .claude/hosts.json — do not re-hardcode them here.
set -uo pipefail

HOSTS_JSON="/home/bosko/NixOS/.claude/hosts.json"

mapfile -t HOSTS < <(jq -r '.flakeHosts[]' "$HOSTS_JSON")
declare -A SSH_TARGET
while IFS=$'\t' read -r name ssh; do
  SSH_TARGET[$name]="$ssh"
done < <(jq -r '.hosts | to_entries[] | select(.value.flakeHost) | "\(.key)\t\(.value.ssh)"' "$HOSTS_JSON")
VPN_SSH="$(jq -r '.hosts["vpn-server"].ssh' "$HOSTS_JSON")"
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
raw=$(ssh -o BatchMode=yes -o ConnectTimeout=8 "$VPN_SSH" 'sudo wg show wg0 latest-handshakes' 2>/dev/null)
if [ -z "${raw:-}" ]; then
  echo "  vpn-server unreachable"
else
  now=$(date +%s)
  while read -r peer hs; do
    [ -z "$peer" ] && continue
    n=$(jq -r --arg p "$peer" '.vpn.peers[$p] // $p' "$HOSTS_JSON")
    if [ "${hs:-0}" -gt 0 ]; then
      printf "  %-16s %ss ago\n" "$n" "$((now - hs))"
    else
      printf "  %-16s never\n" "$n"
    fi
  done <<<"$raw"
fi
