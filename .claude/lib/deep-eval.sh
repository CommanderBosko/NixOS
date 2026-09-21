#!/usr/bin/env bash
#
# deep-eval.sh — Force full evaluation of every member of a flake attribute set.
#
# `nix flake check` only SHALLOWLY verifies nixosConfigurations (it checks the
# toplevel is a derivation without forcing its full eval), so a broken package
# deep in systemPackages sails through it. This script forces each member's
# `config.system.build.toplevel.drvPath` instead — eval only, no builds, no
# secrets decrypted (sops values stay encrypted), cross-arch is fine.
#
# The member list is read live from the flake (`builtins.attrNames`), never a
# hardcoded or hosts.json copy, so a newly added host is checked automatically.
#
# EVERY member is evaluated even when an earlier one fails (a failure is
# recorded and the loop carries on — important under CI's default `bash -e`),
# then a per-member verdict table is printed. Exits 0 only if all passed.
#
# Usage:
#   deep-eval.sh [--flake REF] [--set ATTR] [--list] [NAME...]
#
#   --flake REF   flake to evaluate (default: the repo containing this script)
#   --set ATTR    attribute set whose members are evaluated (default:
#                 nixosConfigurations). Anything shaped like an attrset of NixOS
#                 configs works, e.g. lib.deSmoke.
#   --list        print the member names, one per line, and exit (no evaluation)
#   NAME...       evaluate only these members instead of all of them
#
# Exit: 0 all passed | 1 at least one member failed | 2 usage/enumeration error.
#
# Used by .github/workflows/check.yml (both jobs), the /deep-eval-check skill
# (via its scripts/deep-eval-check.sh wrapper), and check-hosts-json.sh (--list).

set -uo pipefail

FLAKE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SET="nixosConfigurations"
LIST_ONLY=0
NAMES=()

while [ $# -gt 0 ]; do
  case "$1" in
    --flake) FLAKE="${2:?--flake needs a value}"; shift 2 ;;
    --set)   SET="${2:?--set needs a value}"; shift 2 ;;
    --list)  LIST_ONLY=1; shift ;;
    -h|--help)
      # Print this file's leading comment block as the help text.
      awk 'NR > 1 && /^#/ { sub(/^# ?/, ""); print; next } NR > 1 { exit }' "${BASH_SOURCE[0]}"
      exit 0
      ;;
    --*) echo "deep-eval.sh: unknown option: $1" >&2; exit 2 ;;
    *)   NAMES+=("$1"); shift ;;
  esac
done

# Enumerate members straight from the flake, one per line.
if ! all="$(nix eval --raw --apply 'a: builtins.concatStringsSep "\n" (builtins.attrNames a)' "$FLAKE#$SET")"; then
  echo "deep-eval.sh: could not enumerate '$SET' in $FLAKE" >&2
  exit 2
fi

if [ "$LIST_ONLY" -eq 1 ]; then
  printf '%s\n' "$all"
  exit 0
fi

if [ "${#NAMES[@]}" -eq 0 ]; then
  mapfile -t NAMES <<<"$all"
fi

if [ "${#NAMES[@]}" -eq 0 ] || [ -z "${NAMES[0]}" ]; then
  echo "deep-eval.sh: '$SET' has no members to evaluate" >&2
  exit 2
fi

in_ci=0
[ "${GITHUB_ACTIONS:-}" = "true" ] && in_ci=1

errfile="$(mktemp)"
trap 'rm -f "$errfile"' EXIT

pass=(); fail=()

for name in "${NAMES[@]}"; do
  if [ "$in_ci" -eq 1 ]; then echo "::group::$name"; else echo "=== $name ==="; fi

  ok=1
  if drv="$(nix eval --raw "$FLAKE#$SET.$name.config.system.build.toplevel.drvPath" 2>"$errfile")"; then
    echo "PASS: $drv"
    # Surface evaluation warnings (deprecations etc.), minus the dirty-tree noise.
    grep -v '^warning: Git tree' "$errfile" | sed 's/^/  /' || true
    pass+=("$name")
  else
    ok=0
    echo "FAIL:"
    cat "$errfile"
    fail+=("$name")
  fi

  if [ "$in_ci" -eq 1 ]; then
    echo "::endgroup::"
    # Groups are collapsed by default; surface failures as annotations too.
    [ "$ok" -eq 1 ] || echo "::error title=deep-eval failed::$SET.$name failed to evaluate"
  else
    echo
  fi
done

echo "--- deep-eval verdict ($SET) ---"
for name in "${NAMES[@]}"; do
  case " ${fail[*]:-} " in
    *" $name "*) printf 'FAIL  %s\n' "$name" ;;
    *)           printf 'PASS  %s\n' "$name" ;;
  esac
done
echo "${#pass[@]} passed, ${#fail[@]} failed (of ${#NAMES[@]})"

[ "${#fail[@]}" -eq 0 ]
