#!/usr/bin/env bash
#
# hosts.sh — Shared lookups against .claude/hosts.json (the single source of
# truth for host SSH targets, IPs, VPN peer identities). SOURCE this file; do
# not execute it:
#
#   source "$(dirname "${BASH_SOURCE[0]}")/hosts.sh"      # from a .claude/lib script
#   source /home/bosko/NixOS/.claude/lib/hosts.sh         # from a skill script
#
# Sets HOSTS_JSON (default: hosts.json next to this file's .claude/ dir, so it
# also resolves correctly inside a git worktree or a CI checkout; export
# HOSTS_JSON before sourcing to point elsewhere) and defines:
#
#   hosts_jq <jq args...>       raw `jq <args> "$HOSTS_JSON"` escape hatch
#   hosts_flake_names           flake hosts, one per line (.flakeHosts[])
#   hosts_ssh <name>            SSH target for one host; empty output if unknown
#   hosts_table                 key<TAB>ssh<TAB>ip<TAB>notes for every host
#   hosts_flake_ssh_pairs       name<TAB>ssh for every host with flakeHost=true
#   hosts_vpn_ips               every vpnIp in use (one per line)
#   hosts_vpn_peer_name <key>   WireGuard public key -> host name (or the key
#                               itself if it is not a known peer)
#
# Callers keep their own `set -uo pipefail`; nothing here changes shell options.
# Requires jq.
#
# Used by resolve-host.sh and check-hosts-json.sh. Other host-touching skill
# scripts (fleet-status, restore-tunnels, host-age-key, next-vpn-ip, vpn-status)
# still carry their own inline jq lookups and can migrate to these helpers.

HOSTS_JSON="${HOSTS_JSON:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/hosts.json}"

hosts_jq() {
  jq "$@" "$HOSTS_JSON"
}

hosts_flake_names() {
  hosts_jq -r '.flakeHosts[]'
}

hosts_ssh() {
  hosts_jq -r --arg name "${1:-}" '.hosts[$name].ssh // empty'
}

hosts_table() {
  hosts_jq -r '.hosts | to_entries[] | "\(.key)\t\(.value.ssh)\t\(.value.ip // "-")\t\(.value.notes // "")"'
}

hosts_flake_ssh_pairs() {
  hosts_jq -r '.hosts | to_entries[] | select(.value.flakeHost) | "\(.key)\t\(.value.ssh)"'
}

hosts_vpn_ips() {
  hosts_jq -r '.hosts | to_entries[] | select(.value.vpnIp) | .value.vpnIp'
}

hosts_vpn_peer_name() {
  hosts_jq -r --arg pk "${1:-}" '.vpn.peers[$pk] // $pk'
}
