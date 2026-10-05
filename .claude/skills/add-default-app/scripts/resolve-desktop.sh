#!/usr/bin/env bash
# resolve-desktop.sh <nixpkgs-attr> — Step 1 helper: builds the package and prints
# every .desktop file it ships with its MimeType= line, so the right handler and
# its exact filename are read from the package, never guessed.
set -uo pipefail

PKG="${1:-}"
if [[ -z "$PKG" ]]; then
  echo "usage: resolve-desktop.sh <nixpkgs-attr>" >&2
  exit 2
fi

OUT=$(nix build --no-link --print-out-paths "nixpkgs#${PKG}" 2>/dev/null | head -1)
if [[ -z "$OUT" ]]; then
  echo "ERROR: could not build nixpkgs#${PKG}" >&2
  exit 1
fi

DIR="$OUT/share/applications"
if [[ ! -d "$DIR" ]]; then
  echo "(no share/applications in $OUT — package ships no .desktop files)"
  exit 1
fi

for f in "$DIR"/*.desktop; do
  [[ -e "$f" ]] || continue
  echo "== $(basename "$f")"
  grep '^MimeType' "$f" || echo "(no MimeType= line — a bare launcher entry, not a handler)"
done
