#!/usr/bin/env bash
#
# validate-niri-config.sh — Syntax-check the repo's niri config with `niri validate`, which a
# plain `niri validate -c dotfiles/common/configs/niri-config.kdl` cannot do: that file `include`s
# a per-host overlay and DMS-generated files that only exist next to the DEPLOYED config. A
# nixos-dry-run does not help either, because Home Manager just `source`s the .kdl file and never
# parses it.
#
# It builds a scratch copy of the config directory (the shared config.kdl, the host's
# niri-overlay.kdl from this repo, and each other included file taken from ~/.config/niri/ or
# created empty when this machine does not have it), then runs `niri validate -c` on that copy.
# Read-only for the repo and for ~/.config/niri; the scratch dir is deleted on exit.
#
# Usage: validate-niri-config.sh [--config FILE] [--overlay FILE] [HOST]
#   HOST       whose hosts/<HOST>/niri-overlay.kdl to use (default: this machine's hostname;
#              a host with no overlay file validates against an empty one, as Home Manager does)
#   --config   config to check instead of dotfiles/common/configs/niri-config.kdl
#   --overlay  overlay file to use instead of hosts/<HOST>/niri-overlay.kdl
# Env: NIRI_CONFIG_DIR (default ~/.config/niri) is where non-repo includes are looked up.
# Exit: 0 valid; 1 niri reports the config invalid (its message is printed); 2 usage error or
#       unreadable file; 3 `niri` is not installed.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONFIG="$REPO/dotfiles/common/configs/niri-config.kdl"
OVERLAY="" HOST=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --config) CONFIG="${2:?--config needs a file}"; shift 2 ;;
    --overlay) OVERLAY="${2:?--overlay needs a file}"; shift 2 ;;
    -h|--help) sed -n '2,22p' "${BASH_SOURCE[0]}"; exit 0 ;;
    -*) echo "validate-niri-config.sh: unknown flag $1" >&2; exit 2 ;;
    *) HOST="$1"; shift ;;
  esac
done
HOST="${HOST:-$(hostname)}"
DEPLOYED="${NIRI_CONFIG_DIR:-$HOME/.config/niri}"
[ -r "$CONFIG" ] || { echo "validate-niri-config.sh: cannot read $CONFIG" >&2; exit 2; }
[ -n "$OVERLAY" ] || OVERLAY="$REPO/hosts/$HOST/niri-overlay.kdl"
[ -z "$OVERLAY" ] || [ ! -e "$OVERLAY" ] || [ -r "$OVERLAY" ] || { echo "validate-niri-config.sh: cannot read $OVERLAY" >&2; exit 2; }
command -v niri >/dev/null 2>&1 || { echo "validate-niri-config.sh: niri is not installed on this machine" >&2; exit 3; }

SCRATCH="$(mktemp -d)"
trap 'rm -rf "$SCRATCH"' EXIT
cp -L "$CONFIG" "$SCRATCH/config.kdl"

notes=()
# Every `include "<path>"` line outside a comment, in the order they appear.
while IFS= read -r inc; do
  dest="$SCRATCH/$inc"
  mkdir -p "$(dirname "$dest")"
  if [ "$inc" = "niri-overlay.kdl" ]; then
    if [ -r "$OVERLAY" ]; then cp -L "$OVERLAY" "$dest"; notes+=("overlay: $OVERLAY")
    else : >"$dest"; notes+=("overlay: none for host $HOST, validated against an empty one"); fi
  elif [ -r "$DEPLOYED/$inc" ]; then
    cp -L "$DEPLOYED/$inc" "$dest"; notes+=("$inc: copied from $DEPLOYED")
  else
    : >"$dest"; notes+=("$inc: not on this machine, validated against an empty file")
  fi
  chmod u+w "$dest"
done < <(sed -n 's/^[[:space:]]*include[[:space:]]*"\([^"]*\)".*/\1/p' "$SCRATCH/config.kdl")

if niri validate -c "$SCRATCH/config.kdl"; then
  printf 'OK: niri config is valid (host %s)\n' "$HOST"
  [ "${#notes[@]}" -eq 0 ] || printf '  %s\n' "${notes[@]}"
else
  printf 'INVALID: niri rejected the config (host %s)\n' "$HOST" >&2
  exit 1
fi
