#!/usr/bin/env bash
#
# show-pin-state.sh — Show each root flake input's URL and locked rev for /home/bosko/NixOS.
#
# Default: prints one aligned line per root input:
#
#   <name>   <original url, e.g. github:owner/repo/ref>   <locked rev, 12 chars>
#
# With --names: prints just the root input names, one per line (e.g. nixpkgs,
# home-manager, nix-flatpak, dms) — the cheap list /bump-input and /pin-input
# show for the user to pick from.
#
# Reads live from `nix flake metadata --json` — this already resolves any
# `follows` chain to the real node internally, so no hand-rolled flake.lock
# parsing or reference-chasing is needed here.
#
# Usage:
#   show-pin-state.sh            # name / url / locked rev table
#   show-pin-state.sh --names    # input names only
#
# Used by the /pin-input and /bump-input skills.

set -uo pipefail

case "${1:-}" in
  "")      mode="table" ;;
  --names) mode="names" ;;
  *)
    echo "usage: show-pin-state.sh [--names]" >&2
    exit 2
    ;;
esac

meta="$(nix flake metadata /home/bosko/NixOS --json)" || exit 1

if [ "$mode" = "names" ]; then
  printf '%s' "$meta" | jq -r '.locks.nodes.root.inputs | keys[]'
  exit 0
fi

printf '%s' "$meta" | jq -r '
  . as $root
  | $root.locks.nodes.root.inputs as $inputs
  | ($inputs | keys | map(length) | max) as $w
  | $inputs | to_entries[] | .key as $name | .value as $node
  | ($root.locks.nodes[$node].original // {}) as $o
  | ($root.locks.nodes[$node].locked.rev // "?") as $rev
  | ($o.ref // $o.rev // "") as $ref
  | (if $o.type == "github" then
       "github:" + $o.owner + "/" + $o.repo + (if $ref != "" then "/" + $ref else "" end)
     else
       ($o | tostring)
     end) as $url
  | $name + (" " * ($w - ($name | length))) + "   " + $url + "   " + ($rev[0:12])
'
