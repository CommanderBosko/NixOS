#!/usr/bin/env bash
# rollback.sh — READ-ONLY helper for the rollback skill.
# Lists recent system generations and resolves the rollback target (current
# generation minus 1, or a passed target). Unprivileged — reads the profile
# symlinks directly, no sudo. Does NOT activate anything; the skill performs
# the actual `nixos-rebuild switch --rollback` itself after the user confirms.
# Usage: rollback.sh [target-generation]
set -uo pipefail

PROFILES=/nix/var/nix/profiles

CURRENT="$(readlink "$PROFILES/system" 2>/dev/null | sed -n 's/^system-\([0-9]*\)-link$/\1/p')"
if [[ -z "$CURRENT" ]]; then
  echo "ERROR: could not determine current generation from $PROFILES/system" >&2
  exit 1
fi

mapfile -t GENS < <(ls -1 "$PROFILES" 2>/dev/null | sed -n 's/^system-\([0-9]*\)-link$/\1/p' | sort -n)

echo "== recent generations (newest last) =="
for g in "${GENS[@]}"; do
  ts="$(stat -c '%y' "$PROFILES/system-${g}-link" 2>/dev/null | cut -d. -f1)"
  mark=""; [[ "$g" == "$CURRENT" ]] && mark="  <- current"
  printf '  %-5s %s%s\n' "$g" "$ts" "$mark"
done | tail -6

TARGET="${1:-$((CURRENT - 1))}"
echo
echo "current-generation: $CURRENT"
echo "rollback-target:    $TARGET"

if ! printf '%s\n' "${GENS[@]}" | grep -qx "$TARGET"; then
  echo "WARNING: target generation $TARGET not found in the list above" >&2
fi
