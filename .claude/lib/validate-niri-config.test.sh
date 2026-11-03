#!/usr/bin/env bash
# Tests for validate-niri-config.sh. Needs `niri` (skips with exit 0 and a note when it is absent).
# Run: bash .claude/lib/validate-niri-config.test.sh
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SH="$HERE/validate-niri-config.sh"
command -v niri >/dev/null 2>&1 || { echo "validate-niri-config.test.sh: niri not installed, skipped"; exit 0; }
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
pass=0 fail=0
rc_is() { if [ "$2" -eq "$3" ]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL: $1 -- exit $2, wanted $3"; fi; }
export NIRI_CONFIG_DIR="$TMP/none"   # never read the real ~/.config/niri

bash "$SH" gaming >/dev/null 2>&1;                           rc_is "real config + gaming overlay is valid" $? 0
bash "$SH" no-such-host >/dev/null 2>&1;                     rc_is "host without an overlay validates against an empty one" $? 0

printf 'binds {\n    Mod+Q { definitely-not-an-action; }\n}\n' >"$TMP/bad-overlay.kdl"
bash "$SH" --overlay "$TMP/bad-overlay.kdl" gaming >/dev/null 2>&1; rc_is "bad overlay is rejected" $? 1

printf 'this is { not valid kdl\n' >"$TMP/bad-config.kdl"
bash "$SH" --config "$TMP/bad-config.kdl" gaming >/dev/null 2>&1; rc_is "unparseable config is rejected" $? 1

bash "$SH" --config "$TMP/missing.kdl" >/dev/null 2>&1;      rc_is "missing config file is a usage error" $? 2
bash "$SH" --bogus >/dev/null 2>&1;                          rc_is "unknown flag is a usage error" $? 2

echo "validate-niri-config.test.sh: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
