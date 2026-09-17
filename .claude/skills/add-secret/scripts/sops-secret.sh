#!/usr/bin/env bash
# sops-secret.sh — the three everyday sops write operations, sharing the
# SOPS_AGE_KEY_FILE export + nix-shell wrapping so it's written once.
#
# SAFETY: set/create take the value as a FILE PATH, never as an inline
# argument — this script must only ever be run by the USER via a `!`
# command, never by the agent. The agent prepares the exact command text
# (referencing a scratchpad value-file) and hands it to the user to run.
# See modules/sops.nix's comment and this skill's Gotchas for why.
#
# Usage:
#   sops-secret.sh set    <file> <key> <value-file>   # add/update one key in place
#   sops-secret.sh edit   <file>                       # interactive $EDITOR edit
#   sops-secret.sh create <file> <key> <value-file>    # new file, then encrypt in place
set -uo pipefail

export SOPS_AGE_KEY_FILE="$HOME/.config/sops/age/keys.txt"

REPO=/home/bosko/NixOS
MODE="${1:-}"
FILE="${2:-}"

usage() {
  echo "usage: sops-secret.sh {set|edit|create} <file> [key] [value-file]" >&2
  exit 2
}

[[ -z "$MODE" || -z "$FILE" ]] && usage

# Accept either an absolute path or a repo-relative one.
if [[ "$FILE" != /* ]]; then
  FILE="$REPO/$FILE"
fi

case "$MODE" in
  set)
    KEY="${3:-}"; VALUE_FILE="${4:-}"
    [[ -z "$KEY" || -z "$VALUE_FILE" ]] && usage
    [[ -f "$FILE" ]] || { echo "ERROR: file not found: $FILE" >&2; exit 1; }
    [[ -f "$VALUE_FILE" ]] || { echo "ERROR: value file not found: $VALUE_FILE" >&2; exit 1; }
    VALUE="$(cat "$VALUE_FILE")"
    nix shell nixpkgs#sops --command \
      sops set "$FILE" "[\"$KEY\"]" "\"$VALUE\""
    ;;
  edit)
    [[ -f "$FILE" ]] || { echo "ERROR: file not found: $FILE" >&2; exit 1; }
    nix shell nixpkgs#sops --command sops "$FILE"
    ;;
  create)
    KEY="${3:-}"; VALUE_FILE="${4:-}"
    [[ -z "$KEY" || -z "$VALUE_FILE" ]] && usage
    [[ -f "$FILE" ]] && { echo "ERROR: file already exists, use 'set' instead: $FILE" >&2; exit 1; }
    [[ -f "$VALUE_FILE" ]] || { echo "ERROR: value file not found: $VALUE_FILE" >&2; exit 1; }
    VALUE="$(cat "$VALUE_FILE")"
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
