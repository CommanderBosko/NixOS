#!/usr/bin/env bash
set -euo pipefail

# Offline fallback for the search-pkg skill.
# Runs `nix search nixpkgs <query>`, strips the
# legacyPackages.<system>. prefix, reformats each hit into a
# `pkgs.<name> (ver)` block, and truncates to ~80 lines.
#
# Usage: search-pkg.sh <query>

if [ "$#" -lt 1 ] || [ -z "${1:-}" ]; then
  echo "usage: search-pkg.sh <query>" >&2
  exit 2
fi

query="$1"
limit=80

# nix search emits eval-progress spam to stderr; drop it.
raw="$(nix search "nixpkgs#${query}" 2>/dev/null || true)"

if [ -z "$raw" ]; then
  echo "No packages matched \"${query}\"."
  exit 0
fi

# Strip the legacyPackages.<system>. prefix and rewrite the
# attribute line into `  pkgs.<name> (ver)`; indent descriptions.
formatted="$(printf '%s\n' "$raw" | sed -E \
  -e 's/^\* legacyPackages\.[^.]+\.([^ ]+) (\(.*\))$/  pkgs.\1 \2/' \
  -e 's/^\* legacyPackages\.[^.]+\.([^ ]+)$/  pkgs.\1/' \
  -e 's/^([^ ].*)$/  \1/')"

echo "Search results for \"${query}\":"
echo
truncated=0
line_count="$(printf '%s\n' "$formatted" | wc -l)"
if [ "$line_count" -gt "$limit" ]; then
  truncated=1
fi
printf '%s\n' "$formatted" | head -"$limit"

if [ "$truncated" -eq 1 ]; then
  echo
  echo "(Results truncated — use a more specific query to narrow down.)"
fi
