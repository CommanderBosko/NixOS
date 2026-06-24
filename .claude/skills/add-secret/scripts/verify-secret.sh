#!/usr/bin/env bash
# verify-secret.sh — confirm a sops secret file is well-formed.
# Decrypts the file with the admin age key (proves recipients are correct) and
# greps for ENC[ (proves values are actually encrypted on disk, not plaintext).
# Usage: verify-secret.sh <secret-file> [host]   ([host] is currently informational only)
set -uo pipefail

REPO=/home/bosko/NixOS
FILE="${1:-}"
HOST="${2:-}"

if [[ -z "$FILE" ]]; then
  echo "usage: verify-secret.sh <secret-file> [host]" >&2
  exit 2
fi

# Accept either an absolute path or a repo-relative one.
if [[ "$FILE" != /* ]]; then
  FILE="$REPO/$FILE"
fi

if [[ ! -f "$FILE" ]]; then
  echo "ERROR: file not found: $FILE" >&2
  exit 1
fi

export SOPS_AGE_KEY_FILE="$HOME/.config/sops/age/keys.txt"

echo "== Decrypting $FILE${HOST:+ (host: $HOST)} =="
if nix shell nixpkgs#sops --command sops -d "$FILE"; then
  echo "-- decrypt: OK"
else
  echo "-- decrypt: FAILED" >&2
  exit 1
fi

echo
if grep -q 'ENC\[' "$FILE"; then
  echo "-- encrypted-on-disk: OK (ENC[ present)"
else
  echo "-- encrypted-on-disk: FAILED (no ENC[ markers — file may be plaintext!)" >&2
  exit 1
fi
