#!/usr/bin/env bash
# Tests for pi-host.sh against a fixture hosts.json (never the real one).
# Run: bash .claude/lib/pi-host.test.sh
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
cat >"$TMP/hosts.json" <<'JSON'
{
  "flakeHosts": ["gaming", "mypi"],
  "hosts": {
    "gaming": { "ssh": "bosko@gaming", "tailscaleIp": "100.1.1.1", "flakeHost": true, "arch": "x86_64-linux" },
    "mypi":   { "ssh": "bosko@mypi", "tailscaleIp": "100.2.2.2", "flakeHost": true, "arch": "aarch64-linux", "aliases": ["thepi"] },
    "noip":   { "ssh": "bosko@noip", "flakeHost": false }
  }
}
JSON
export HOSTS_JSON="$TMP/hosts.json" PI_BACKUP_ROOT="$TMP/bk" PI_REPO="/repo"
pass=0 fail=0
ok() { if [ "$2" = "$3" ]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL: $1 -- got '$2', wanted '$3'"; fi; }
# Each case runs in its own bash -c: pi_die exits the shell it runs in.
run() { "$@" 2>&1; }

ok "load by key"      "$(run bash -c 'source "$0"; pi_load mypi; echo "$PI_IP $PI_ARCH $PI_TARGET $PI_BACKUP_DIR"' "$HERE/pi-host.sh")" "100.2.2.2 aarch64-linux bosko@100.2.2.2 $TMP/bk/mypi"
ok "load by alias"    "$(run bash -c 'source "$0"; pi_load thepi; echo "$PI_NAME"' "$HERE/pi-host.sh")" "mypi"
ok "ip override wins" "$(run bash -c 'source "$0"; pi_load mypi 9.9.9.9; echo "$PI_TARGET"' "$HERE/pi-host.sh")" "bosko@9.9.9.9"
ok "unregistered host + ip" "$(run bash -c 'source "$0"; pi_load pi-hole 100.9.9.9; echo "$PI_NAME $PI_ARCH $PI_TARGET"' "$HERE/pi-host.sh")" "pi-hole aarch64-linux bosko@100.9.9.9"
out="$(run bash -c 'source "$0"; pi_load noip' "$HERE/pi-host.sh")"; rc=$?
ok "no ip is an error (rc)" "$rc" "1"
case "$out" in *"no tailscaleIp"*) ok "no ip message" 1 1 ;; *) ok "no ip message" "$out" "contains 'no tailscaleIp'" ;; esac
out="$(run bash -c 'source "$0"; pi_load gaming; pi_require_aarch64' "$HERE/pi-host.sh")"; rc=$?
ok "x86 host is not a Pi (rc)" "$rc" "1"
ok "image attr"    "$(run bash -c 'source "$0"; pi_load mypi; pi_flake_ref image' "$HERE/pi-host.sh")" "/repo#nixosConfigurations.mypi.config.system.build.sdImage"
ok "toplevel attr" "$(run bash -c 'source "$0"; pi_load mypi; pi_attr toplevel' "$HERE/pi-host.sh")" "nixosConfigurations.mypi.config.system.build.toplevel"
out="$(run bash -c 'source "$0"; pi_attr bogus' "$HERE/pi-host.sh")"; rc=$?
ok "bad attr kind (rc)" "$rc" "1"

echo "pi-host.test.sh: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
