#!/usr/bin/env bash
# audit-sweep.sh — deterministic part of the config audit.
# Emits raw secret-pattern hits across all *.nix files for the model to TRIAGE
# (option references like passwordFile=... are NOT findings; only literal
# embedded secrets are). Optionally runs the slow `nix flake check` when called
# with `--flake-check`.
set -uo pipefail

REPO=/home/bosko/NixOS

echo "== secret-pattern sweep (*.nix) =="
echo "# Triage: distinguish OPTION REFERENCES (passwordFile=, .path) from LITERAL embedded secrets."
grep -rniE 'private[_-]?key|password|secret|token|presharedkey|api[_-]?key' \
  "$REPO" --include=*.nix
grep_status=$?
# grep exit 1 == no matches (fine); >1 == real error.
if [[ $grep_status -gt 1 ]]; then
  echo "ERROR: grep failed (status $grep_status)" >&2
  exit "$grep_status"
fi
[[ $grep_status -eq 1 ]] && echo "(no secret-pattern hits)"

if [[ "${1:-}" == "--flake-check" ]]; then
  echo
  echo "== nix flake check (slow — eval-level errors) =="
  nix flake check "$REPO" 2>&1
fi

exit 0
