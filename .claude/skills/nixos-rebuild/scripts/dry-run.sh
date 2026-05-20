#!/usr/bin/env bash
# dry-run.sh — Preview NixOS changes without applying them.
# Run this before rebuild.sh to show the user what will change.
set -euo pipefail

FLAKE_PATH="/home/bosko/NixOS"

echo "==> NixOS dry-run preview (no changes will be applied)"
echo "    Flake: ${FLAKE_PATH}"
echo ""

nh os boot "${FLAKE_PATH}" --dry
