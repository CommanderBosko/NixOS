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
# With --temp-pins: prints only inputs whose locked `original` (in flake.lock)
# names a rev or ref that the flake.nix url does not name, plus every pin
# recorded in .claude/temp-pins (one `<input> <rev> [reason]` per line, written
# by /pin-input) whose rev is still the locked one. One line each; no output
# means no pin was found. The registry is needed because
# `nix flake lock --override-input` leaves `original` equal to the flake.nix url,
# so the lock alone can't show that pin.
#
# Reads live from `nix flake metadata --json` — this already resolves any
# `follows` chain to the real node internally, so no hand-rolled flake.lock
# parsing or reference-chasing is needed here.
#
# Usage:
#   show-pin-state.sh                # name / url / locked rev table
#   show-pin-state.sh --names        # input names only
#   show-pin-state.sh --temp-pins    # inputs pinned to a rev/ref flake.nix doesn't name
#
# FLAKE_DIR overrides the flake directory (default: this repo), for tests.
#
# Used by the /pin-input, /bump-input and /update skills.

set -uo pipefail

FLAKE_DIR="${FLAKE_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

case "${1:-}" in
  "")           mode="table" ;;
  --names)      mode="names" ;;
  --temp-pins)  mode="temp-pins" ;;
  *)
    echo "usage: show-pin-state.sh [--names|--temp-pins]" >&2
    exit 2
    ;;
esac

if [ "$mode" = "temp-pins" ]; then
  # url per root input from flake.nix; null for follows-only inputs (skipped below).
  urls="$(nix eval --json --impure --expr "let f = import $FLAKE_DIR/flake.nix; in builtins.mapAttrs (_: v: v.url or null) f.inputs")" || exit 1
  # Reads flake.lock from disk, not `nix flake metadata`: metadata relocks in memory when flake.nix and the lock disagree.
  jq -rn --argjson urls "$urls" --slurpfile lock "$FLAKE_DIR/flake.lock" '
    $lock[0] as $l
    | $l.nodes.root.inputs | to_entries[] | .key as $name | .value as $node
    | select($node | type == "string")
    | ($l.nodes[$node].original // {}) as $o
    | ($urls[$name] // null) as $url
    | select($url != null)
    | ($url | split("[/?&=]"; null)) as $tokens
    | ($o.rev // "") as $rev
    | ($o.ref // "") as $ref
    | (if $rev != "" and (any($tokens[]; . as $t | ($t == $rev) or ($t | length >= 7 and ($rev | startswith($t)))) | not)
       then "rev " + $rev[0:12] else null end) as $revHit
    | (if $ref != "" and (any($tokens[]; . == $ref) | not)
       then "ref " + $ref else null end) as $refHit
    | ([$revHit, $refHit] | map(select(. != null))) as $hits
    | select($hits | length > 0)
    | $name + "  pinned to " + ($hits | join(" and ")) + " not named in flake.nix (" + $url + ")"
  ' || exit 1
  reg="$FLAKE_DIR/.claude/temp-pins"
  if [ -f "$reg" ]; then
    while read -r name rev reason; do
      case "$name" in ""|\#*) continue ;; esac
      locked="$(jq -r --arg n "$name" '.nodes.root.inputs[$n] as $k | if ($k | type) == "string" then .nodes[$k].locked.rev // "" else "" end' "$FLAKE_DIR/flake.lock")"
      if [ -n "$locked" ] && [[ $locked == "$rev"* ]]; then
        echo "$name  temporary pin to rev ${rev:0:12} recorded in .claude/temp-pins${reason:+ ($reason)}"
      else
        echo "$name  stale .claude/temp-pins entry: lock is at ${locked:0:12}, not ${rev:0:12}; remove the line"
      fi
    done < "$reg"
  fi
  exit 0
fi

meta="$(nix flake metadata "$FLAKE_DIR" --json)" || exit 1

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
