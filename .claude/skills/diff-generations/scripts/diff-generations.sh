#!/usr/bin/env bash
# diff-generations.sh — store-closure diff between the PREVIOUS and CURRENT NixOS
# generation. Read-only. Resolves the previous generation robustly: the highest
# generation number strictly below the current one that still exists on disk
# (the old "system-1-link" shortcut was wrong — that's literally generation 1).
set -uo pipefail

CURRENT="/run/current-system"
PROFILES="/nix/var/nix/profiles"

if [ ! -e "$CURRENT" ]; then
  echo "ERROR: $CURRENT is missing or unreadable." >&2
  exit 1
fi

cur_n=$(readlink "$PROFILES/system" 2>/dev/null | sed -n 's/^system-\([0-9]*\)-link$/\1/p')
if [ -z "${cur_n:-}" ]; then
  echo "ERROR: could not resolve the current generation number from $PROFILES/system." >&2
  exit 1
fi

# Largest generation number strictly less than the current one, that still exists.
prev_n=""
while read -r g; do
  [ "$g" -lt "$cur_n" ] && prev_n=$g
done < <(ls -1 "$PROFILES" 2>/dev/null | sed -n 's/^system-\([0-9]*\)-link$/\1/p' | sort -n)

if [ -z "$prev_n" ]; then
  echo "No previous generation to compare against (current is generation $cur_n)." >&2
  exit 2
fi

prev="$PROFILES/system-${prev_n}-link"
echo "==> Diffing generation ${prev_n} -> ${cur_n}"
echo "    $prev"
echo "    $CURRENT"
echo
nix store diff-closures "$prev" "$CURRENT"
