#!/usr/bin/env bash
# next-vpn-ip.sh — determine the next available VPN peer address, the
# server's current public key, and the server's current endpoint, for the
# /new-peer skill (Steps 2 and 4).
#
# Runs read-only lookups (never guesses/hardcodes):
#   1. hosts.json vpnIp values (flake hosts that already have an entry)
#   2. every address in the VPN subnet literally assigned in the vpn-server config
#      (covers ad-hoc peers — phones, non-NixOS devices — with no hosts.json entry)
# then takes the higher of the two highest octets and adds 1. The subnet itself
# is .vpn.subnet in .claude/hosts.json (must be a /24 — last-octet logic). The public key and
# endpoint are both read live from modules/vpn.nix so a future endpoint change
# (this is a cloud VM's public IP) can't silently go stale in a template.
#
# Output (three lines on stdout):
#   NEXT_IP=<next free address in .vpn.subnet>
#   SERVER_PUBKEY=<key>
#   SERVER_ENDPOINT=<ip:port>
set -uo pipefail

# Relative to this script (as in render-client-conf.sh), so it also works from a git worktree.
SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO="$(cd "$SKILL_DIR/../../.." && pwd)"
source "$REPO/.claude/lib/hosts.sh"
VPN_SERVER_CONF="$REPO/hosts/vpn-server/wireguard.nix"
VPN_MODULE="$REPO/modules/vpn.nix"

SUBNET="$(hosts_jq -r '.vpn.subnet // empty')"
case "$SUBNET" in
  */24) ;;
  *) echo "next-vpn-ip.sh: expected a /24 .vpn.subnet in $HOSTS_JSON, got '${SUBNET}'" >&2; exit 1 ;;
esac
NET_PREFIX="${SUBNET%.*}."        # 10.10.0.0/24 -> 10.10.0.
NET_RE="${NET_PREFIX//./\\.}"    # -> 10\.10\.0\.

FROM_HOSTS_JSON=$(hosts_vpn_ips | awk -F. '{print $4}' | sort -n | tail -1)

FROM_SERVER_CONF=$(grep -oE "${NET_RE}[0-9]+" "$VPN_SERVER_CONF" \
  | awk -F. '{print $4}' | sort -n | tail -1)

FROM_HOSTS_JSON="${FROM_HOSTS_JSON:-0}"
FROM_SERVER_CONF="${FROM_SERVER_CONF:-0}"

HIGHEST=$FROM_HOSTS_JSON
if [ "$FROM_SERVER_CONF" -gt "$HIGHEST" ]; then
  HIGHEST=$FROM_SERVER_CONF
fi

if [ "$HIGHEST" -eq 0 ]; then
  echo "next-vpn-ip.sh: found no existing ${NET_PREFIX}x addresses in either source — refusing to guess a starting point" >&2
  exit 1
fi

NEXT=$((HIGHEST + 1))
if [ "$NEXT" -gt 254 ]; then
  echo "next-vpn-ip.sh: ${SUBNET} is full (highest in use: ${NET_PREFIX}${HIGHEST})" >&2
  exit 1
fi
echo "NEXT_IP=${NET_PREFIX}${NEXT}"

PUBKEY=$(grep -oE 'publicKey = "[^"]+"' "$VPN_MODULE" | head -1 | sed -E 's/publicKey = "([^"]+)"/\1/')
if [ -z "$PUBKEY" ]; then
  echo "next-vpn-ip.sh: could not find server publicKey in $VPN_MODULE" >&2
  exit 1
fi
echo "SERVER_PUBKEY=${PUBKEY}"

ENDPOINT=$(grep -oE 'endpoint = "[^"]+"' "$VPN_MODULE" | head -1 | sed -E 's/endpoint = "([^"]+)"/\1/')
if [ -z "$ENDPOINT" ]; then
  echo "next-vpn-ip.sh: could not find server endpoint in $VPN_MODULE" >&2
  exit 1
fi
echo "SERVER_ENDPOINT=${ENDPOINT}"
