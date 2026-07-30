#!/usr/bin/env bash
set -euo pipefail

# Print the tunnel-restart command for every full-tunnel client after a
# vpn-server reboot (rebooting the server drops every client's handshake —
# see the remote-rebuild skill's Gotchas). Iterates hosts.json's flakeHosts,
# skipping vpn-server itself.
#
# READ-ONLY: does not run the restart itself. None of these hosts have a
# NOPASSWD sudo rule (only vpn-server does), so a non-interactive
# `ssh ... sudo systemctl restart` here would just fail with "a terminal is
# required to read the password." Print the exact command per host and hand
# off — the user runs each one themselves (or via the `!` prefix locally).

HOSTS_JSON="/home/bosko/NixOS/.claude/hosts.json"

for host in $(jq -r '.flakeHosts[]' "$HOSTS_JSON"); do
  [ "$host" = "vpn-server" ] && continue
  ssh_target="$(jq -r ".hosts[\"$host\"].ssh" "$HOSTS_JSON")"
  echo "$host ($ssh_target):"
  if [ "$host" = "$(hostname)" ]; then
    echo "  sudo systemctl restart wg-quick-wg0"
  else
    echo "  ssh $ssh_target 'sudo systemctl restart wg-quick-wg0'"
  fi
done
