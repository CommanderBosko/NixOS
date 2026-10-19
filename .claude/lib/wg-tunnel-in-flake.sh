#!/usr/bin/env bash
#
# wg-tunnel-in-flake.sh — Is the WireGuard client tunnel (modules/vpn.nix) in the
# flake right now? Reads flake.nix live, so re-adding or removing the import
# in desktopModules is picked up with no edit here.
#
#   wg-tunnel-in-flake.sh [FLAKE_NIX]
#
#   FLAKE_NIX   path to flake.nix (default: the repo containing this script)
#
# Exit: 0 tunnel imported by desktopModules | 1 not imported | 2 flake.nix unreadable.
# Commented-out lines are ignored, so a `# "${self}/modules/vpn.nix"` line reads as "out".
#
# Used by fleet-status.sh (skips the WireGuard section when out) and
# remote-rebuild's restore-tunnels.sh (nothing to restart when out).

set -uo pipefail

FLAKE="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/flake.nix}"

if [ ! -r "$FLAKE" ]; then
  echo "wg-tunnel-in-flake: cannot read $FLAKE" >&2
  exit 2
fi

# Count matches with grep -c (reads all input), not grep -q, so pipefail can't trip on SIGPIPE.
hits=$(grep -v '^[[:space:]]*#' "$FLAKE" \
  | awk '/^[[:space:]]*desktopModules[[:space:]]*=/,/^[[:space:]]*\];/' \
  | grep -cE '^[[:space:]]*"\$\{self\}/modules/vpn\.nix"')

[ "${hits:-0}" -gt 0 ]
