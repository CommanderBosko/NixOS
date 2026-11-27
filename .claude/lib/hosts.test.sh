#!/usr/bin/env bash
# Tests for the fleet-exclusion lookups in hosts.sh against a fixture hosts.json
# (never the real one). Run: bash .claude/lib/hosts.test.sh
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
cat >"$TMP/hosts.json" <<'JSON'
{
  "flakeHosts": ["gaming", "dns", "mypi", "blank"],
  "hosts": {
    "gaming": { "ssh": "bosko@gaming", "flakeHost": true },
    "dns":    { "ssh": "bosko@dns", "flakeHost": true, "fleetExclude": "household DNS: reboot takes it down" },
    "mypi":   { "ssh": "bosko@mypi", "flakeHost": true, "fleetExclude": null },
    "blank":  { "ssh": "bosko@blank", "flakeHost": true, "fleetExclude": "" },
    "other":  { "ssh": "bosko@other", "flakeHost": false, "fleetExclude": "not a flake host" }
  }
}
JSON
export HOSTS_JSON="$TMP/hosts.json"
source "$HERE/hosts.sh"
pass=0 fail=0
ok() { if [ "$2" = "$3" ]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL: $1 -- got '$2', wanted '$3'"; fi; }

ok "rollout set skips only the excluded host" "$(hosts_fleet_rollout_names | tr '\n' ' ')" "gaming mypi blank "
ok "excluded list has name and reason" "$(hosts_fleet_excluded)" "$(printf 'dns\thousehold DNS: reboot takes it down')"
ok "flake host list is unchanged" "$(hosts_flake_names | tr '\n' ' ')" "gaming dns mypi blank "
ok "a non-flake host never appears" "$(hosts_fleet_excluded | grep -c '^other')" "0"

echo "hosts.test.sh: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
