#!/usr/bin/env bash
# Deep-evaluate a single unwired desktop-environment module via lib.deSmoke.
# With no argument, lists the available module names instead.
set -uo pipefail

REPO="/home/bosko/NixOS"

if [ -z "${1:-}" ]; then
  nix eval "$REPO#lib.deSmoke" --apply builtins.attrNames --json
  exit 0
fi

NAME="$1"

if drv=$(nix eval --raw "$REPO#lib.deSmoke.$NAME.config.system.build.toplevel.drvPath" 2>&1); then
  echo "PASS: $drv"
else
  echo "FAIL:"
  echo "$drv"
  exit 1
fi
