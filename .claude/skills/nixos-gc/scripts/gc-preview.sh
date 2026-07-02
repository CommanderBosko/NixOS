#!/usr/bin/env bash
# gc-preview.sh — READ-ONLY helper for the nixos-gc skill.
# Lists system generations and which ones gc.sh would delete (all but the 3
# most recent), by reading the profile symlinks directly. Unprivileged — no
# sudo, safe to run automatically. Does NOT delete anything.
set -uo pipefail

PROFILES=/nix/var/nix/profiles

mapfile -t GENS < <(ls -1 "$PROFILES" 2>/dev/null | sed -n 's/^system-\([0-9]*\)-link$/\1/p' | sort -n)

if [ "${#GENS[@]}" -eq 0 ]; then
  echo "ERROR: could not find any system-*-link generations under $PROFILES" >&2
  exit 1
fi

echo "== all generations (oldest first) =="
for g in "${GENS[@]}"; do
  ts="$(stat -c '%y' "$PROFILES/system-${g}-link" 2>/dev/null | cut -d. -f1)"
  printf '  %-5s %s\n' "$g" "$ts"
done

TOTAL="${#GENS[@]}"
if [ "$TOTAL" -le 3 ]; then
  echo
  echo "==> 3 or fewer generations exist — nothing would be deleted."
else
  KEEP=("${GENS[@]: -3}")
  DELETE=("${GENS[@]:0:$((TOTAL - 3))}")
  echo
  echo "==> Would KEEP:   ${KEEP[*]}"
  echo "==> Would DELETE: ${DELETE[*]}"
fi
