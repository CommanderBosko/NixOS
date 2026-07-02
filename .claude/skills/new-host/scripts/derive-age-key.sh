#!/usr/bin/env bash
# derive-age-key.sh <hostname> — Derive a host's sops-nix age recipient key.
#
# SSHes to the host, reads its SSH ed25519 host public key, and converts it
# to an age public key via ssh-to-age. Prints only the public age key (safe
# to paste into .sops.yaml) — never touches the host's private key.
#
# Usage: derive-age-key.sh <hostname-or-ssh-target>
set -euo pipefail

if [ $# -ne 1 ]; then
  echo "Usage: $0 <hostname-or-ssh-target>" >&2
  exit 1
fi

TARGET="$1"

ssh "bosko@${TARGET}" 'cat /etc/ssh/ssh_host_ed25519_key.pub' \
  | nix shell nixpkgs#ssh-to-age --command ssh-to-age
