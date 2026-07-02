#!/usr/bin/env bash
#
# list-flake-inputs.sh — List the root flake inputs for /home/bosko/NixOS.
#
# Prints one input name per line (e.g. nixpkgs, home-manager, nix-flatpak, dms),
# read live from `nix flake metadata --json` rather than a hardcoded list.
#
# Usage:
#   list-flake-inputs.sh
#
# Used by the /bump-input and /pin-input skills.

set -uo pipefail

nix flake metadata /home/bosko/NixOS --json | jq -r '.locks.nodes.root.inputs | keys[]'
