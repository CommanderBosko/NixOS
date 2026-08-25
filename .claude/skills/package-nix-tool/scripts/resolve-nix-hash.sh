#!/usr/bin/env bash
# Builds a pkgs/<name>.nix derivation against the flake's own nixpkgs input
# and prints the real hash Nix reports on a fixed-output-hash mismatch — the
# "set a fake hash, build, read the real one out of the error" trick used to
# resolve both fetchFromGitHub's `hash` and buildNpmPackage's `npmDepsHash`
# (or buildGoModule's `vendorHash`, rustPlatform's `cargoHash`, etc.)
# without a separate prefetch tool. This is the exact command this repo's
# tailscale-mcp package was resolved with (both its src hash and its
# npmDepsHash).
#
# Run once PER HASH FIELD: set that field to lib.fakeHash
# ("sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="), run this script,
# paste the printed hash into the field, then move to the next field. Fields
# must be resolved outermost-first — a wrong/fake `src.hash` mismatch is
# reported before Nix ever gets far enough to evaluate a deps hash beneath
# it, so resolve `src.hash` first, then npmDepsHash/vendorHash/cargoHash.
#
# Usage: resolve-nix-hash.sh <pkgs-file-relative-to-repo-root> [system]
# Example: resolve-nix-hash.sh pkgs/some-tool.nix
#
# Exit 0 -> the real hash, and only the real hash, printed on stdout
# Exit 2 -> build already succeeded (no mismatch left to resolve for this field)
# Exit 1 -> a real build error, not a hash mismatch; tail of build output on stderr

set -euo pipefail

if [ $# -lt 1 ] || [ $# -gt 2 ]; then
  echo "Usage: $0 <pkgs-file-relative-to-repo-root> [system]" >&2
  exit 1
fi

pkg_file="$1"
system="${2:-x86_64-linux}"
repo_root="/home/bosko/NixOS"

if [ ! -f "$repo_root/$pkg_file" ]; then
  echo "error: $repo_root/$pkg_file not found" >&2
  exit 1
fi

set +e
out=$(cd "$repo_root" && timeout 300 nix build --no-link --print-out-paths --impure --expr \
  "let flake = builtins.getFlake (toString ./.); pkgs = flake.inputs.nixpkgs.legacyPackages.${system}; in pkgs.callPackage ./${pkg_file} {}" 2>&1)
status=$?
set -e

if [ "$status" -eq 0 ]; then
  echo "Build succeeded — no hash mismatch left to resolve for this field." >&2
  exit 2
fi

got=$(printf '%s\n' "$out" | grep -A2 "hash mismatch" | grep "got:" | awk '{print $2}' | head -1 || true)

if [ -n "$got" ]; then
  echo "$got"
  exit 0
else
  printf '%s\n' "$out" | tail -40 >&2
  exit 1
fi
