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

source /home/bosko/NixOS/.claude/lib/hosts.sh

# Guard: the wg-quick-wg0 unit only exists on a desktop host while
# modules/vpn.nix is imported by desktopModules. It is currently commented out
# (Oracle admin-disabled vpn-server 2026-08-18 — see the
# project_vpn_server_oracle_disabled memory), so there is nothing to restart.
# Gaming's `vpn` variant still imports it, but only as an explicit opt-in.
if ! awk '/^[[:space:]]*desktopModules[[:space:]]*=/,/^[[:space:]]*\];/' /home/bosko/NixOS/flake.nix \
     | grep -qE '^[[:space:]]*"\$\{self\}/modules/vpn\.nix"'; then
  echo "tunnel module currently pulled from desktopModules (modules/vpn.nix commented out in flake.nix) — no wg-quick-wg0 unit on any desktop host, nothing to restart."
  exit 0
fi

for host in $(hosts_flake_names); do
  [ "$host" = "vpn-server" ] && continue
  ssh_target="$(hosts_ssh "$host")"
  echo "$host ($ssh_target):"
  if [ "$host" = "$(hostname)" ]; then
    echo "  sudo systemctl restart wg-quick-wg0"
  else
    echo "  ssh $ssh_target 'sudo systemctl restart wg-quick-wg0'"
  fi
done
