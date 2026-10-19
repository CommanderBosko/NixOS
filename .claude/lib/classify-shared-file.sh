#!/usr/bin/env bash
#
# classify-shared-file.sh — Decide whether an edit to a given repo file could
# affect more than one NixOS host, by reading flake.nix live rather than
# trusting a hardcoded copy of its module lists.
#
# A file counts as SHARED if any of:
#   (a) it's flake.nix or flake.lock (every host), or anything under
#       dotfiles/ (Home Manager configs — home-manager is in desktopModules,
#       so they reach every desktop host), or
#   (b) it's listed inside the commonModules/desktopModules array bodies
#       (used by every desktop host, or every host, via `++`), or
#   (c) its path string appears directly in 2+ places elsewhere in flake.nix —
#       catching a module wired into multiple hosts' own per-host module
#       lists without going through the two named arrays (e.g.
#       modules/desktop-environments/niri.nix, pulled in via gamingModules for
#       gaming, laptopModules for laptop, and directly by natalie-laptop's
#       host block), or
#   (d) it's a modules/ file imported by another modules/ file that is SHARED
#       by (b) or (c) — one level only (e.g. modules/dms-shell.nix, imported by
#       modules/desktop-environments/niri.nix).
# Comment lines in flake.nix and in importers are ignored, so a comment naming
# a path (e.g. the commented-out vpn.nix line) doesn't count as wiring it in.
# Anything else is LOCAL — host-specific, no cross-host impact.
#
# Usage: classify-shared-file.sh <file-path> [flake.nix path]
# Prints exactly one line: "SHARED: <reason>" or "LOCAL".
# Exit 0 always (this is a classifier, not a pass/fail check).

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
file="${1:?usage: classify-shared-file.sh <file-path> [flake.nix path]}"
flake="${2:-$REPO/flake.nix}"

# Normalize to a repo-relative path (strip a leading repo-root prefix if given).
repo_root="$(cd "$(dirname "$flake")" && pwd)"
rel="${file#"$repo_root"/}"
rel="${rel#/}"

# (a) Files that reach every (desktop) host without being named in a module list.
case "$rel" in
  flake.nix)  echo "SHARED: is flake.nix itself"; exit 0 ;;
  flake.lock) echo "SHARED: is flake.lock (pins inputs for every host)"; exit 0 ;;
  dotfiles/*) echo "SHARED: under dotfiles/ (Home Manager, via desktopModules)"; exit 0 ;;
esac

# flake.nix minus comment lines.
flake_code="$(grep -v '^[[:space:]]*#' "$flake" || true)"
# (b)'s region: from the commonModules definition through the first
# "mkSystem =" line (end of desktopModules; per-host module lists follow).
arrays_text="$(sed -n '/commonModules = \[/,/mkSystem =/p' <<<"$flake_code")"

# Print the (b)/(c) SHARED reason for a repo-relative path; return 1 if neither.
direct_shared() {
  local p="$1" count
  if grep -qF "$p" <<<"$arrays_text"; then
    echo "listed in commonModules/desktopModules"
    return 0
  fi
  # (c) Referenced directly 2+ times (bypassing the named arrays — a module
  # wired into multiple hosts' own per-host module lists).
  count="$(grep -c -F "$p" <<<"$flake_code" || true)"
  if [[ "$count" -ge 2 ]]; then
    echo "referenced directly in $count places in flake.nix"
    return 0
  fi
  return 1
}

if reason="$(direct_shared "$rel")"; then
  echo "SHARED: $reason"
  exit 0
fi

# (d) Imported (non-comment line) by a modules/ file that is itself SHARED.
if [[ "$rel" == modules/*.nix ]]; then
  while IFS= read -r importer; do
    imp_rel="${importer#"$repo_root"/}"
    [[ "$imp_rel" == "$rel" ]] && continue
    grep -v '^[[:space:]]*#' "$importer" | grep -qF "$rel" || continue
    if reason="$(direct_shared "$imp_rel")"; then
      echo "SHARED: imported by $imp_rel ($reason)"
      exit 0
    fi
  done < <(grep -rlsF --include='*.nix' "$rel" "$repo_root/modules" || true)
fi

echo "LOCAL"
