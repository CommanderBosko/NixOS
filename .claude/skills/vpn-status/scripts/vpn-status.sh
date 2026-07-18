#!/usr/bin/env bash
# vpn-status.sh — Check WireGuard peer status on the Oracle Cloud VPN server.
# Safe: read-only. SSHes to the server and runs 'sudo wg show wg0 dump', then
# parses it locally into a ready-to-show table: resolves each peer's public
# key to a hostname via .claude/hosts.json's `.vpn.peers` map, classifies
# connection status against fixed thresholds (Active <=180s, Idle
# 180s-1800s, Offline >1800s or never), and formats transfer bytes.
# The vpn-server SSH target and peer roster are read from the single source
# of truth at .claude/hosts.json — do not re-hardcode either here.
set -euo pipefail

HOSTS_JSON="/home/bosko/NixOS/.claude/hosts.json"
VPN_SSH="$(jq -r '.hosts["vpn-server"].ssh' "$HOSTS_JSON")"

echo "==> WireGuard VPN status — ${VPN_SSH}"
echo ""

DUMP="$(ssh \
  -o BatchMode=yes \
  -o ConnectTimeout=10 \
  -o StrictHostKeyChecking=accept-new \
  "${VPN_SSH}" \
  "sudo wg show wg0 dump")"

NOW="$(date +%s)"

fmt_bytes() {
  local b="$1"
  if [ "$b" -ge 1073741824 ]; then
    awk -v b="$b" 'BEGIN { printf "%.1f GiB", b/1073741824 }'
  elif [ "$b" -ge 1048576 ]; then
    awk -v b="$b" 'BEGIN { printf "%.1f MiB", b/1048576 }'
  elif [ "$b" -ge 1024 ]; then
    awk -v b="$b" 'BEGIN { printf "%.1f KiB", b/1024 }'
  else
    echo "${b} B"
  fi
}

fmt_ago() {
  local delta="$1"
  if [ "$delta" -lt 60 ]; then
    echo "${delta} seconds ago"
  elif [ "$delta" -lt 3600 ]; then
    echo "$((delta / 60)) minutes ago"
  else
    echo "$((delta / 3600)) hours ago"
  fi
}

# First line of `wg show <iface> dump` is the interface itself
# (private-key public-key listen-port fwmark) — skip it. Peer lines are
# public-key preshared-key endpoint allowed-ips latest-handshake rx tx keepalive.
printf "%-16s %-8s %-22s %s\n" "Peer" "Status" "Last Handshake" "Transfer (rx/tx)"

echo "$DUMP" | tail -n +2 | while IFS=$'\t' read -r pubkey _psk _endpoint _allowed hs rx tx _keepalive; do
  name="$(jq -r --arg pk "$pubkey" '.vpn.peers[$pk] // ("unknown:" + ($pk[0:12]))' "$HOSTS_JSON")"

  if [ "$hs" = "0" ]; then
    status="Offline"
    ago="never"
  else
    delta=$((NOW - hs))
    ago="$(fmt_ago "$delta")"
    if [ "$delta" -le 180 ]; then
      status="Active"
    elif [ "$delta" -le 1800 ]; then
      status="Idle"
    else
      status="Offline"
    fi
  fi

  transfer="$(fmt_bytes "$rx") / $(fmt_bytes "$tx")"
  printf "%-16s %-8s %-22s %s\n" "$name" "$status" "$ago" "$transfer"
done
