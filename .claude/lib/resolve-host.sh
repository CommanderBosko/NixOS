#!/usr/bin/env bash
#
# resolve-host.sh — Resolve a short host name to its SSH target.
#
# Normalizes known aliases, then looks up `.hosts["<name>"].ssh` in
# /home/bosko/NixOS/.claude/hosts.json (via the shared hosts.sh helpers) —
# never hardcode a copy of that map.
#
# On success: prints just the resolved SSH target (e.g. "bosko@gaming") to
# stdout and exits 0.
# On failure (no name given, or name not found): prints the full host table
# (key, ssh, ip, notes — tab-separated) to stdout and exits 1, so a caller
# can fall back to presenting that table via AskUserQuestion.
#
# Usage:
#   resolve-host.sh <name>
#
# Used by the /ssh-host and /journal skills.

set -uo pipefail

# Shared hosts.json lookups (HOSTS_JSON, hosts_table, hosts_ssh).
source "$(dirname "${BASH_SOURCE[0]}")/hosts.sh"

NAME="${1:-}"

if [ -z "$NAME" ]; then
  hosts_table
  exit 1
fi

case "$NAME" in
  natalie) NAME="natalie-laptop" ;;
  vpn|oracle|server) NAME="vpn-server" ;;
esac

TARGET="$(hosts_ssh "$NAME")"

if [ -z "$TARGET" ]; then
  hosts_table
  exit 1
fi

echo "$TARGET"
