#!/usr/bin/env bash
# sops-secret.sh — the three everyday sops write operations, sharing the
# SOPS_AGE_KEY_FILE export + nix-shell wrapping so it's written once.
# Usage:
#   sops-secret.sh set    <file> <key> <value>   # add/update one key in place
#   sops-secret.sh edit   <file>                 # interactive $EDITOR edit
#   sops-secret.sh create <file> <key> <value>   # new file, then encrypt in place
set -uo pipefail

export SOPS_AGE_KEY_FILE="$HOME/.config/sops/age/keys.txt"

REPO=/home/bosko/NixOS
MODE="${1:-}"
FILE="${2:-}"

usage() {
  echo "usage: sops-secret.sh {set|edit|create} <file> [key] [value]" >&2
  exit 2
}

[[ -z "$MODE" || -z "$FILE" ]] && usage

# Accept either an absolute path or a repo-relative one.
if [[ "$FILE" != /* ]]; then
  FILE="$REPO/$FILE"
fi

case "$MODE" in
  set)
    KEY="${3:-}"; VALUE="${4:-}"
    [[ -z "$KEY" || -z "$VALUE" ]] && usage
    [[ -f "$FILE" ]] || { echo "ERROR: file not found: $FILE" >&2; exit 1; }
    nix shell nixpkgs#sops --command \
      sops set "$FILE" "[\"$KEY\"]" "\"$VALUE\""
    ;;
  edit)
    [[ -f "$FILE" ]] || { echo "ERROR: file not found: $FILE" >&2; exit 1; }
    nix shell nixpkgs#sops --command sops "$FILE"
    ;;
  create)
    KEY="${3:-}"; VALUE="${4:-}"
    [[ -z "$KEY" || -z "$VALUE" ]] && usage
    [[ -f "$FILE" ]] && { echo "ERROR: file already exists, use 'set' instead: $FILE" >&2; exit 1; }
    nix shell nixpkgs#sops --command bash -c '
      umask 077
      printf "%s: \"%s\"\n" "$1" "$2" > "$3"
      sops -e -i "$3"
    ' _ "$KEY" "$VALUE" "$FILE"
    ;;
  *)
    usage
    ;;
esac
