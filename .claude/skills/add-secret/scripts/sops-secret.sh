#!/usr/bin/env bash
# sops-secret.sh — the three everyday sops write operations, sharing the
# SOPS_AGE_KEY_FILE export + nix-shell wrapping so it's written once.
#
# SAFETY: set/create take the value as a FILE PATH, never as an inline
# argument — this script must only ever be run by the USER, never by the
# agent. The agent prepares the exact command text (referencing a scratchpad
# value-file) and hands it to the user. Running it via `!` is fine because the
# command carries only a file path — but the value-file itself must be written
# from a separate terminal, never with a `!` command (that echoes the value
# into the transcript).
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
    # sops wants a JSON-encoded value. jq encodes the raw file safely (newlines,
    # quotes, backslashes all survive) and rtrimstr drops the single trailing
    # newline a heredoc/printf adds; --value-file keeps the value out of argv.
    JSON_FILE="$(umask 077; mktemp)"
    trap 'rm -f "$JSON_FILE"' EXIT
    nix shell nixpkgs#jq --command jq -Rs 'rtrimstr("\n")' < "$VALUE_FILE" > "$JSON_FILE" || exit 1
    nix shell nixpkgs#sops --command \
      sops set --value-file "$FILE" "[\"$KEY\"]" "$JSON_FILE"
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
    # Build the file with jq (--rawfile + rtrimstr), NOT printf into a quoted YAML
    # scalar: YAML folds a raw newline inside a double-quoted string into a space,
    # which silently turned a two-line env-file secret into one line. Content is
    # JSON, which the .yaml-typed sops parse accepts; sops re-emits it as YAML.
    (umask 077; nix shell nixpkgs#jq --command \
      jq -n --arg k "$KEY" --rawfile v "$VALUE_FILE" '{($k): ($v | rtrimstr("\n"))}' > "$FILE") || { rm -f "$FILE"; exit 1; }
    nix shell nixpkgs#sops --command sops -e -i "$FILE" || { rm -f "$FILE"; exit 1; }
    ;;
  *)
    usage
    ;;
esac
