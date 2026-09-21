#!/usr/bin/env bash
# host-age-key.sh — derive a host's age public key from its SSH ed25519 host key.
# Used to add a new host anchor under keys: in .sops.yaml.
# Usage: host-age-key.sh <host>
set -uo pipefail

HOST="${1:-}"
if [[ -z "$HOST" ]]; then
  echo "usage: host-age-key.sh <host>" >&2
  exit 2
fi

source /home/bosko/NixOS/.claude/lib/hosts.sh
SSH_TARGET="$(hosts_ssh "$HOST")"
if [[ -z "$SSH_TARGET" ]]; then
  echo "error: no .hosts[\"$HOST\"].ssh entry in $HOSTS_JSON" >&2
  exit 2
fi

ssh "$SSH_TARGET" 'cat /etc/ssh/ssh_host_ed25519_key.pub' \
  | nix shell nixpkgs#ssh-to-age --command ssh-to-age
