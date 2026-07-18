#!/usr/bin/env bash
# current-de.sh <host> — print the currently active desktop-environment
# module name (no .nix suffix) for a given host, parsed from that host's
# own block in flake.nix (never assumes; scopes strictly to that host so it
# can't accidentally match another host's DE line).
#
# Exit codes:
#   0  exactly one DE module found — printed on stdout
#   1  no host block found, or no DE module found in that block
#   2  ambiguous — more than one DE module found in the host's block
#      (all candidates printed to stderr; caller should ask the user)
set -uo pipefail

HOST="${1:?usage: current-de.sh <host>}"
FLAKE="/home/bosko/NixOS/flake.nix"

BLOCK=$(awk -v host="$HOST" '
  BEGIN { depth = 0; capturing = 0 }
  capturing == 0 && $0 ~ ("^[[:space:]]*" host "[[:space:]]*=[[:space:]]*mkSystem[[:space:]]*\\{") {
    capturing = 1
  }
  capturing == 1 {
    print
    n = gsub(/\{/, "{"); depth += n
    n = gsub(/\}/, "}"); depth -= n
    if (depth <= 0) exit
  }
' "$FLAKE")

if [ -z "$BLOCK" ]; then
  echo "current-de.sh: no host block found for '$HOST' in flake.nix" >&2
  exit 1
fi

MATCHES=$(echo "$BLOCK" | grep -oE 'desktop-environments/[A-Za-z0-9_-]+\.nix' | sed -E 's#desktop-environments/##; s#\.nix$##' | sort -u)
COUNT=$(printf '%s\n' "$MATCHES" | grep -c .)

if [ "$COUNT" -eq 0 ]; then
  echo "current-de.sh: no desktop-environments module found in '$HOST' block (headless host?)" >&2
  exit 1
elif [ "$COUNT" -gt 1 ]; then
  echo "current-de.sh: ambiguous — multiple DE modules found for '$HOST':" >&2
  printf '%s\n' "$MATCHES" >&2
  exit 2
fi

printf '%s\n' "$MATCHES"
