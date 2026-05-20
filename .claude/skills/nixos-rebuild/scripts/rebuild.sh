#!/usr/bin/env bash
# rebuild.sh — Stage NixOS rebuild for next boot.
# HIGH RISK: modifies bootloader default entry.
# Only run after dry-run.sh has been shown to the user and they confirmed with YES.
set -euo pipefail

FLAKE_PATH="/home/bosko/NixOS"

echo "==> Staging NixOS rebuild for next boot"
echo "    Flake: ${FLAKE_PATH}"
echo "    The running system will NOT change until you reboot."
echo ""

nh os boot "${FLAKE_PATH}"

echo ""
echo "==> Rebuild staged successfully."
echo "    Reboot to activate the new configuration."
