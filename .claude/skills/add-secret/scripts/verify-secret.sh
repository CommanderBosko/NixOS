#!/usr/bin/env bash
# verify-secret.sh — confirm a sops secret file is well-formed, without ever
# printing decrypted plaintext to stdout (the whole file's decrypt used to be
# echoed here — fixed, since that leaked every secret in the file, not just
# the one being checked).
#
# Usage:
#   verify-secret.sh <secret-file> [host]
#     General health check: file decrypts, and looks encrypted on disk
#     (ENC[ present). Prints only OK/FAILED, never plaintext.
#
#   verify-secret.sh <secret-file> --key <sops-key-path> --expect <value-file>
#     Confirms one specific key round-trips to an expected value, e.g. right
#     after a `set`. Prints only a masked match/mismatch
#     (first4...last4), never the full value.
set -uo pipefail

REPO=/home/bosko/NixOS
FILE="${1:-}"

usage() {
  echo "usage: verify-secret.sh <secret-file> [host]" >&2
  echo "       verify-secret.sh <secret-file> --key <sops-key-path> --expect <value-file>" >&2
  exit 2
}

[[ -z "$FILE" ]] && usage

if [[ "$FILE" != /* ]]; then
  FILE="$REPO/$FILE"
fi

if [[ ! -f "$FILE" ]]; then
  echo "ERROR: file not found: $FILE" >&2
  exit 1
fi

export SOPS_AGE_KEY_FILE="$HOME/.config/sops/age/keys.txt"

if [[ "${2:-}" == "--key" ]]; then
  KEY_PATH="${3:-}"
  [[ "${4:-}" == "--expect" ]] || usage
  VALUE_FILE="${5:-}"
  [[ -z "$KEY_PATH" || -z "$VALUE_FILE" ]] && usage
  [[ -f "$VALUE_FILE" ]] || { echo "ERROR: expected-value file not found: $VALUE_FILE" >&2; exit 1; }

  DECRYPTED="$(nix shell nixpkgs#sops --command sops -d --extract "$KEY_PATH" "$FILE" 2>&1)"
  EXPECTED="$(cat "$VALUE_FILE")"

  if [[ "$DECRYPTED" == "$EXPECTED" ]]; then
    echo "MATCH — round-trips correctly (${DECRYPTED:0:4}...${DECRYPTED: -4})"
    exit 0
  else
    echo "MISMATCH — decrypted value does not match expected value" >&2
    exit 1
  fi
fi

HOST="${2:-}"

echo "== Checking $FILE${HOST:+ (host: $HOST)} =="
if nix shell nixpkgs#sops --command sops -d "$FILE" >/dev/null 2>&1; then
  echo "-- decrypt: OK"
else
  echo "-- decrypt: FAILED" >&2
  exit 1
fi

if grep -q 'ENC\[' "$FILE"; then
  echo "-- encrypted-on-disk: OK (ENC[ present)"
else
  echo "-- encrypted-on-disk: FAILED (no ENC[ markers — file may be plaintext!)" >&2
  exit 1
fi
