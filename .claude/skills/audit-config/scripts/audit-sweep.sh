#!/usr/bin/env bash
# audit-sweep.sh — deterministic part of the config audit.
# Emits raw secret-pattern hits across all *.nix files for the model to TRIAGE
# (option references like passwordFile=... are NOT findings; only literal
# embedded secrets are). Optionally runs the slow `nix flake check` when called
# with `--flake-check`. With `--hardening`, also greps for each security.nix
# guarantee (and any override of it) so the model can judge regressions.
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

for arg in "$@"; do
  case "$arg" in
    --hardening)
      echo
      echo "== hardening guarantees (security.nix) and any overrides elsewhere =="
      echo "# Judge: anything silently disabled, mkForce'd, or overridden per host is a finding."
      grep -rnE 'apparmor|killUnconfinedConfinables|audit(d)?\.enable|wheelOnly|execWheelOnly|kexec|protectKernelImage|randomize_va_space' \
        "$REPO/modules" "$REPO/hosts" --include=*.nix || echo "(no hardening-option hits)"
      ;;
    --flake-check)
      echo
      echo "== nix flake check (slow — eval-level errors) =="
      nix flake check "$REPO" 2>&1
      ;;
  esac
done

exit 0
