#!/usr/bin/env bash
# vpn-status.sh — Check WireGuard peer status on the Oracle Cloud VPN server.
# Safe: read-only. SSHes to the server and runs 'sudo wg show'.
# The vpn-server SSH target is read from the single source of truth at
# .claude/hosts.json — do not re-hardcode it here.
set -euo pipefail

HOSTS_JSON="/home/bosko/NixOS/.claude/hosts.json"
VPN_SSH="$(jq -r '.hosts["vpn-server"].ssh' "$HOSTS_JSON")"

echo "==> WireGuard VPN status — ${VPN_SSH}"
echo ""

ssh \
  -o BatchMode=yes \
  -o ConnectTimeout=10 \
  -o StrictHostKeyChecking=accept-new \
  "${VPN_SSH}" \
  "sudo wg show"
