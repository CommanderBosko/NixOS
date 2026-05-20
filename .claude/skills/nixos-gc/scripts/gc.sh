#!/usr/bin/env bash
# gc.sh — Garbage collect old Nix store paths and system generations.
# HIGH RISK: permanently deletes generations older than the 3 most recent. Irreversible.
# Only run after explicit YES confirmation from the user.
set -euo pipefail

echo "==> Current system profile generations"
sudo nix-env -p /nix/var/nix/profiles/system --list-generations
echo ""

# Collect generation numbers older than the 3 most recent, sorted descending.
OLD_GENS=$(
  sudo nix-env -p /nix/var/nix/profiles/system --list-generations \
    | awk '{print $1}' \
    | sort -rn \
    | tail -n +4
)

if [ -z "$OLD_GENS" ]; then
  echo "==> 3 or fewer generations exist — nothing to delete."
else
  echo "==> Deleting old generations: $(echo "$OLD_GENS" | tr '\n' ' ')"
  echo "$OLD_GENS" \
    | xargs --no-run-if-empty sudo nix-env -p /nix/var/nix/profiles/system --delete-generations
  echo "==> Generation symlinks removed."
fi

echo ""
echo "==> Collecting Nix store garbage"
sudo nix-store --gc

echo ""
echo "==> Garbage collection complete."
