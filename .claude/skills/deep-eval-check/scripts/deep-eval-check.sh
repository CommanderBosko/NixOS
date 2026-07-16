#!/usr/bin/env bash
# Deep-evaluate every flake host's build graph (not just a shallow "is it a
# derivation" check). Host list is read live from .claude/hosts.json's
# .flakeHosts — never hardcode it here.
set -uo pipefail

REPO="/home/bosko/NixOS"
HOSTS=$(jq -r '.flakeHosts[]' "$REPO/.claude/hosts.json")

overall=0
for host in $HOSTS; do
  echo "=== $host ==="
  if drv=$(nix eval --raw "$REPO#nixosConfigurations.$host.config.system.build.toplevel.drvPath" 2>&1); then
    echo "PASS: $drv"
  else
    echo "FAIL:"
    echo "$drv"
    overall=1
  fi
  echo
done

exit $overall
