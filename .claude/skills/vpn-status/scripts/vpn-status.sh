#!/usr/bin/env bash
# vpn-status.sh — Check WireGuard peer status on the Oracle Cloud VPN server.
# Safe: read-only. SSHes to the server and runs 'sudo wg show'.
set -euo pipefail

VPN_HOST="150.136.232.63"
SSH_USER="ubuntu"
SSH_KEY="${HOME}/.ssh/id_ed25519"

echo "==> WireGuard VPN status — ${SSH_USER}@${VPN_HOST}"
echo ""

SSH_AUTH_SOCK="" ssh \
  -i "${SSH_KEY}" \
  -o IdentitiesOnly=yes \
  -o ConnectTimeout=10 \
  -o StrictHostKeyChecking=accept-new \
  "${SSH_USER}@${VPN_HOST}" \
  "sudo wg show"
