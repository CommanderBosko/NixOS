#!/usr/bin/env bash
set -euo pipefail

# Restart the WireGuard tunnel on every full-tunnel client after a vpn-server
# reboot (rebooting the server drops every client's handshake — see the
# remote-rebuild skill's Gotchas). Iterates hosts.json's flakeHosts, skipping
# vpn-server itself.

HOSTS_JSON="/home/bosko/NixOS/.claude/hosts.json"

for host in $(jq -r '.flakeHosts[]' "$HOSTS_JSON"); do
  [ "$host" = "vpn-server" ] && continue
  ssh_target="$(jq -r ".hosts[\"$host\"].ssh" "$HOSTS_JSON")"
  echo "Restarting wg-quick-wg0 on $host ($ssh_target)..."
  if ssh -o ConnectTimeout=10 "$ssh_target" "sudo systemctl restart wg-quick-wg0"; then
    echo "  OK"
  else
    echo "  FAILED — $host may be offline or unreachable"
  fi
done
