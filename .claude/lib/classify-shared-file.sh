#!/usr/bin/env bash
#
# classify-shared-file.sh — Decide whether an edit to a given repo file could
# affect more than one NixOS host, by reading flake.nix live rather than
# trusting a hardcoded copy of its module lists.
#
# A file counts as SHARED if either:
#   (a) it's flake.nix itself, or
#   (b) it's listed inside the commonModules/desktopModules array bodies
#       (used by every desktop host, or every host, via `++`), or
#   (c) its path string appears directly in 2+ places elsewhere in flake.nix —
#       catching a module wired into multiple hosts' own per-host module
#       lists without going through the two named arrays (e.g.
#       modules/desktop-environments/niri.nix, imported directly by gaming's
#       and natalie-laptop's host blocks and via laptopModules for laptop).
# Anything else is LOCAL — host-specific, no cross-host impact.
#
# Usage: classify-shared-file.sh <file-path> [flake.nix path]
# Prints exactly one line: "SHARED: <reason>" or "LOCAL".
# Exit 0 always (this is a classifier, not a pass/fail check).

set -euo pipefail

file="${1:?usage: classify-shared-file.sh <file-path> [flake.nix path]}"
flake="${2:-/home/bosko/NixOS/flake.nix}"

# Normalize to a repo-relative path (strip a leading repo-root prefix if given).
repo_root="$(cd "$(dirname "$flake")" && pwd)"
rel="${file#"$repo_root"/}"
rel="${rel#/}"

if [[ "$rel" == "flake.nix" ]]; then
  echo "SHARED: is flake.nix itself"
  exit 0
fi

# (b) Inside the commonModules/desktopModules array bodies?
# Extract from "commonModules = [" through the desktopModules array's closing "];"
# — i.e. everything up to the first "mkSystem =" line, which is where the
# per-host module lists begin.
arrays_text="$(sed -n '1,/mkSystem =/p' "$flake")"
if grep -qF "$rel" <<<"$arrays_text"; then
  echo "SHARED: listed in commonModules/desktopModules"
  exit 0
fi

# (c) Referenced directly 2+ times anywhere in flake.nix (bypassing the named
# arrays — a module wired into multiple hosts' own per-host module lists).
count="$(grep -c -F "$rel" "$flake" || true)"
if [[ "$count" -ge 2 ]]; then
  echo "SHARED: referenced directly in $count places in flake.nix"
  exit 0
fi

echo "LOCAL"
