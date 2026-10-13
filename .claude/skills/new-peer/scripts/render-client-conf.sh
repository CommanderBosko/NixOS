#!/usr/bin/env bash
#
# render-client-conf.sh — Render the raw wg-quick client config for a
# non-NixOS /new-peer device (Step 4) from assets/client.conf.tmpl.
#
# Fills every placeholder except <their-private-key>, which stays literal: the
# private key is generated on, and never leaves, the device.
#
#   <address>            ADDRESS arg (Step 2's NEXT_IP); must sit inside
#                        .vpn.subnet and not be the server's own vpnIp
#   <prefix>             prefix length of .vpn.subnet in .claude/hosts.json
#   <server-public-key>  SERVER_PUBKEY arg (Step 2, read live from modules/vpn.nix)
#   <server-endpoint>    .vpn.endpoint in .claude/hosts.json
#
# Usage:
#   render-client-conf.sh <address> <server-public-key>
#
#   Both args also accept next-vpn-ip.sh's raw lines (NEXT_IP=..., SERVER_PUBKEY=...).
#
# Prints the finished config on stdout; writes nothing. Exits 1 (message on
# stderr) on a bad address or key, or if modules/vpn.nix still carries a
# literal endpoint that disagrees with hosts.json's .vpn.endpoint (one of the
# two is stale — fix that before handing a config to a device).
#
# Paths resolve relative to this script, so it also works from a git worktree.

set -uo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO="$(cd "$SKILL_DIR/../../.." && pwd)"
TEMPLATE="$SKILL_DIR/assets/client.conf.tmpl"
VPN_MODULE="$REPO/modules/vpn.nix"

# Shared hosts.json lookups (HOSTS_JSON, hosts_jq).
source "$REPO/.claude/lib/hosts.sh"

die() { echo "render-client-conf.sh: $*" >&2; exit 1; }

[ $# -eq 2 ] || die "usage: render-client-conf.sh <address> <server-public-key>"

ADDRESS="${1#NEXT_IP=}"
PUBKEY="${2#SERVER_PUBKEY=}"

ip2int() {
  local a b c d
  IFS=. read -r a b c d <<<"$1"
  echo $(( (a << 24) | (b << 16) | (c << 8) | d ))
}

is_ipv4() {
  [[ "$1" =~ ^([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})$ ]] || return 1
  local o
  for o in "${BASH_REMATCH[@]:1}"; do [ "$o" -le 255 ] || return 1; done
}

is_ipv4 "$ADDRESS" || die "not an IPv4 address: '$ADDRESS' (pass Step 2's NEXT_IP)"
[[ "$PUBKEY" =~ ^[A-Za-z0-9+/]{43}=$ ]] || die "not a WireGuard public key: '$PUBKEY' (pass Step 2's SERVER_PUBKEY)"

SUBNET="$(hosts_jq -r '.vpn.subnet // empty')"
ENDPOINT="$(hosts_jq -r '.vpn.endpoint // empty')"
SERVER_VPN_IP="$(hosts_jq -r '.hosts[.vpn.serverHost].vpnIp // empty')"
[ -n "$SUBNET" ] || die "no .vpn.subnet in $HOSTS_JSON"
[ -n "$ENDPOINT" ] || die "no .vpn.endpoint in $HOSTS_JSON"

NET="${SUBNET%/*}"
PREFIX="${SUBNET#*/}"
is_ipv4 "$NET" && [[ "$PREFIX" =~ ^[0-9]+$ ]] && [ "$PREFIX" -le 32 ] \
  || die "malformed .vpn.subnet '$SUBNET' in $HOSTS_JSON"

MASK=$(( PREFIX == 0 ? 0 : (0xFFFFFFFF << (32 - PREFIX)) & 0xFFFFFFFF ))
ADDR_INT="$(ip2int "$ADDRESS")"
NET_INT=$(( $(ip2int "$NET") & MASK ))
BCAST_INT=$(( NET_INT | (~MASK & 0xFFFFFFFF) ))

[ $(( ADDR_INT & MASK )) -eq "$NET_INT" ] || die "$ADDRESS is outside the VPN subnet $SUBNET"
[ "$ADDR_INT" -ne "$NET_INT" ] && [ "$ADDR_INT" -ne "$BCAST_INT" ] \
  || die "$ADDRESS is the network/broadcast address of $SUBNET"
[ "$ADDRESS" != "$SERVER_VPN_IP" ] || die "$ADDRESS is the VPN server's own address"

# Drift guard: while modules/vpn.nix still hard-types the endpoint, it must
# match hosts.json, or the desktop clients and this config would disagree.
if [ -f "$VPN_MODULE" ]; then
  MODULE_ENDPOINT="$(grep -oE 'endpoint = "[^"]+"' "$VPN_MODULE" | head -1 | sed -E 's/endpoint = "([^"]+)"/\1/')"
  if [ -n "$MODULE_ENDPOINT" ] && [ "$MODULE_ENDPOINT" != "$ENDPOINT" ]; then
    die "endpoint mismatch: hosts.json .vpn.endpoint=$ENDPOINT but modules/vpn.nix has $MODULE_ENDPOINT"
  fi
fi

[ -r "$TEMPLATE" ] || die "template not found: $TEMPLATE"
CONF="$(cat "$TEMPLATE")"
CONF="${CONF//"<address>"/"$ADDRESS"}"
CONF="${CONF//"<prefix>"/"$PREFIX"}"
CONF="${CONF//"<server-public-key>"/"$PUBKEY"}"
CONF="${CONF//"<server-endpoint>"/"$ENDPOINT"}"

LEFT="$(grep -oE '<[a-z-]+>' <<<"$CONF" | grep -vx '<their-private-key>' | sort -u)"
[ -z "$LEFT" ] || die "unfilled placeholder(s) in $TEMPLATE: $(echo "$LEFT" | paste -sd' ' -)"

printf '%s\n' "$CONF"
