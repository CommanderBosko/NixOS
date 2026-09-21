#!/usr/bin/env bash
#
# check-hosts-json.sh — Assert .claude/hosts.json's flake hosts equal the
# flake's real nixosConfigurations.
#
# hosts.json is the source of truth the host-touching skills read (ssh-host,
# fleet-status, fleet-rollout, remote-rebuild, ...). If a host is added to or
# dropped from flake.nix without updating it, those skills silently act on the
# wrong fleet. This compares, as sorted sets:
#
#   1. hosts.json `.flakeHosts[]`
#   2. hosts.json keys under `.hosts` whose `flakeHost` is true
#   3. `builtins.attrNames nixosConfigurations` (via deep-eval.sh --list)
#
# Prints each mismatch and exits 1 on any drift; exits 0 (with an OK line)
# when all three agree. Eval-only, read-only. Run by .github/workflows/check.yml.
#
# Usage:
#   check-hosts-json.sh

set -uo pipefail

LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$LIB/hosts.sh"

if ! flake_hosts="$("$LIB/deep-eval.sh" --list)"; then
  echo "check-hosts-json.sh: could not list nixosConfigurations" >&2
  exit 2
fi

sorted() { LC_ALL=C sort -u; }

expected="$(printf '%s\n' "$flake_hosts" | sorted)"
listed="$(hosts_flake_names | sorted)"
flagged="$(hosts_jq -r '.hosts | to_entries[] | select(.value.flakeHost) | .key' | sorted)"

rc=0
compare() {
  local label="$1" have="$2" only_flake only_json
  [ "$have" = "$expected" ] && return 0
  rc=1
  only_flake="$(comm -23 <(printf '%s\n' "$expected") <(printf '%s\n' "$have"))"
  only_json="$(comm -13 <(printf '%s\n' "$expected") <(printf '%s\n' "$have"))"
  echo "MISMATCH: $label differs from nixosConfigurations"
  [ -n "$only_flake" ] && printf '    only in flake:      %s\n' $only_flake
  [ -n "$only_json" ]  && printf '    only in hosts.json: %s\n' $only_json
  return 0
}

compare "hosts.json .flakeHosts" "$listed"
compare "hosts.json .hosts[].flakeHost == true" "$flagged"

if [ "$rc" -eq 0 ]; then
  echo "OK: hosts.json flake hosts match nixosConfigurations ($(printf '%s' "$expected" | tr '\n' ' ' | sed 's/ $//'))"
fi

exit "$rc"
