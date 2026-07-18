#!/usr/bin/env bash
#
# show-pin-state.sh — Show each root flake input's URL and locked rev for /home/bosko/NixOS.
#
# Prints one aligned line per root input:
#
#   <name>   <original url, e.g. github:owner/repo/ref>   <locked rev, 12 chars>
#
# Reads live from `nix flake metadata --json` — this already resolves any
# `follows` chain to the real node internally, so no hand-rolled flake.lock
# parsing or reference-chasing is needed here.
#
# Usage:
#   show-pin-state.sh
#
# Used by the /pin-input skill.

set -uo pipefail

nix flake metadata /home/bosko/NixOS --json | jq -r '
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
