#!/usr/bin/env bash
# dry-run.sh — Preview NixOS changes without applying them.
# Safe: read-only. Does not modify system state.
set -euo pipefail

FLAKE_PATH="/home/bosko/NixOS"

echo "==> NixOS dry-run preview (no changes will be applied)"
echo "    Flake: ${FLAKE_PATH}"
echo ""

nh os boot "${FLAKE_PATH}" --dry
