#!/usr/bin/env bash
# dry-run.sh — Preview NixOS changes without applying them.
# Safe: read-only. Does not modify system state.
set -uo pipefail

FLAKE_PATH="/home/bosko/NixOS"

echo "==> NixOS dry-run preview (no changes will be applied)"
echo "    Flake: ${FLAKE_PATH}"
echo ""

OUTPUT=$(nh os boot "${FLAKE_PATH}" --dry 2>&1)
STATUS=$?
echo "$OUTPUT"

if [ "$STATUS" -ne 0 ]; then
  echo ""
  echo "==> Dry-run failed (exit $STATUS) — see error output above."
  exit "$STATUS"
fi

# Keyword heuristics over the diff to decide whether the resulting build is
# safe to apply live (`nh os switch`) or should be staged for next boot
# (`nh os boot` + reboot). Order matters: reboot-mandatory changes win over
# session-risk changes.
REBOOT_PATTERN='linux-[0-9]|linux-firmware|initrd|systemd-boot|boot\.loader|kernel-modules|/boot/'

# Session-risk keywords: static infra (display manager, GPU driver, graphics
# stack) plus every desktop-environment module name, derived live from
# modules/desktop-environments/ so a newly-added DE is covered automatically
# instead of silently falling through to the wrong (switch) recommendation.
# This previously only covered 3 of 12 DE modules by hand (found by the
# 2026-08-09 skill-audit sweep).
STATIC_RISK_KEYWORDS='sddm|nvidia|greetd|xorg-server|mesa-|wayland-protocols|gnome-shell'
DE_MODULE_NAMES=$(ls "${FLAKE_PATH}"/modules/desktop-environments/*.nix 2>/dev/null | xargs -n1 basename -s .nix | paste -sd'|')
SESSION_RISK_PATTERN="${STATIC_RISK_KEYWORDS}${DE_MODULE_NAMES:+|${DE_MODULE_NAMES}}"

echo ""
echo "==> Switch vs boot recommendation"

if echo "$OUTPUT" | grep -qiE "$REBOOT_PATTERN"; then
  echo "RECOMMENDATION: boot"
  echo "Reason: kernel, initrd, firmware, or bootloader changes detected. These only take"
  echo "effect after a reboot regardless — 'nh os switch' would not fully apply them live."
  echo "Run 'nh os boot' and reboot when convenient."
elif echo "$OUTPUT" | grep -qiE "$SESSION_RISK_PATTERN"; then
  echo "RECOMMENDATION: boot"
  echo "Reason: display manager, graphics driver, or desktop environment/compositor changes"
  echo "detected. Applying these live via 'nh os switch' risks crashing or logging out the"
  echo "current session. Prefer 'nh os boot' and reboot at a convenient time."
else
  echo "RECOMMENDATION: switch"
  echo "Reason: no kernel, bootloader, firmware, display-manager, graphics-driver, or"
  echo "compositor changes detected. Safe to apply immediately with 'nh os switch' to get"
  echo "the change now, without a reboot."
fi
