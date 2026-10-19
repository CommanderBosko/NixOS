#!/usr/bin/env bash
# derive-age-key.sh <hostname> — Derive a host's sops-nix age recipient key.
#
# SSHes to the host, reads its SSH ed25519 host public key, and converts it
# to an age public key via ssh-to-age. Prints only the public age key (safe
# to paste into .sops.yaml) — never touches the host's private key.
#
# Usage: derive-age-key.sh <hostname-or-ssh-target>
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO="$(cd "$SKILL_DIR/../../.." && pwd)"

if [ $# -ne 1 ]; then
  echo "Usage: $0 <hostname-or-ssh-target>" >&2
  exit 1
fi

# Known host name/alias -> its hosts.json SSH target; anything else (a new
# host's IP, or an explicit user@host) is used as-is.
TARGET="$(bash "$REPO/.claude/lib/resolve-host.sh" "$1")" || TARGET="$1"

ssh "$TARGET" 'cat /etc/ssh/ssh_host_ed25519_key.pub' \
  | nix shell nixpkgs#ssh-to-age --command ssh-to-age
