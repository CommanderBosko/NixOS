#!/usr/bin/env bash
# Build gaming's generated mimeapps.list and confirm a given mimetype maps
# to the expected .desktop entry, instead of just trusting a clean eval.
set -uo pipefail

MIMETYPE="${1:?usage: verify-mimeapps.sh <mimetype>}"
ERR_FILE=$(mktemp)
trap 'rm -f "$ERR_FILE"' EXIT

if ! OUT_PATH=$(nix build --no-link --print-out-paths --impure --expr \
  '(builtins.getFlake (toString /home/bosko/NixOS)).nixosConfigurations.gaming.config.home-manager.users.bosko.xdg.configFile."mimeapps.list".source' \
  2>"$ERR_FILE"); then
  echo "build failed:"
  cat "$ERR_FILE"
  exit 1
fi

MATCH=$(grep "$MIMETYPE" "$OUT_PATH" || true)

if [ -z "$MATCH" ]; then
  echo "not found: $MIMETYPE"
  exit 1
fi

echo "$MATCH"
