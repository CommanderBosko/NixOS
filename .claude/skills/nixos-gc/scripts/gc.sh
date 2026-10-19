#!/usr/bin/env bash
# gc.sh — Garbage collect old Nix store paths and system generations.
# HIGH RISK: permanently deletes old generations. Irreversible.
# Only run after the user picks Proceed at SKILL.md's AskUserQuestion gate.
# Which generations to delete comes from `gc-preview.sh --delete-list`, the same
# list the preview shows, so the current, booted and running generations are never deleted.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROFILE=/nix/var/nix/profiles/system

echo "==> Current system profile generations"
sudo nix-env -p "$PROFILE" --list-generations
echo ""

OLD_GENS="$("$SCRIPT_DIR/gc-preview.sh" --delete-list)"

if [ -z "$OLD_GENS" ]; then
  echo "==> Nothing to delete."
else
  echo "==> Deleting generations: $(echo "$OLD_GENS" | tr '\n' ' ')"
  echo "$OLD_GENS" \
    | xargs --no-run-if-empty sudo nix-env -p "$PROFILE" --delete-generations
  echo "==> Generation symlinks removed."
fi

echo ""
echo "==> Collecting Nix store garbage"
sudo nix-store --gc

echo ""
echo "==> Garbage collection complete."
