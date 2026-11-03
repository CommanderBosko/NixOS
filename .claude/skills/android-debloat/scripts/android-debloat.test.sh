#!/usr/bin/env bash
# Tests for android-debloat's scripts. Uses fixture files and a stub `adb`; no device is touched.
# Run: bash android-debloat.test.sh
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLAN_SH="$HERE/plan-debloat.sh"
APPLY_SH="$HERE/apply-batch.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
pass=0 fail=0

ok() { pass=$((pass + 1)); }
bad() { fail=$((fail + 1)); echo "FAIL: $*"; }
expect_line() { # <description> <output> <exact line>
  if grep -qxF -- "$3" <<<"$2"; then ok; else bad "$1 -- missing line: $3"; fi
}
expect_no_line() {
  if grep -qxF -- "$3" <<<"$2"; then bad "$1 -- unexpected line: $3"; else ok; fi
}
expect_rc() { # <description> <got> <want>
  if [ "$2" -eq "$3" ]; then ok; else bad "$1 -- exit $2, wanted $3"; fi
}

# --- fixtures -----------------------------------------------------------------------------------
# Installed list: plain `package:` lines, one CRLF line, one `-f` style line.
printf 'package:com.vendor.ads\r\npackage:com.vendor.news\npackage:com.vendor.keepme\npackage:/system/app/X/X.apk=com.vendor.tvplus\npackage:com.google.android.gms\npackage:com.tailscale.ipn\npackage:com.vendor.third\n' >"$TMP/installed.txt"
cat >"$TMP/candidates.txt" <<'EOF'
# community list
com.vendor.ads
com.vendor.news   # trailing comment
com.vendor.keepme
com.vendor.tvplus
com.google.android.gms
com.tailscale.ipn
com.vendor.notinstalled
com.vendor.ads
EOF
printf 'com.vendor.keepme\n\n# a comment\n' >"$TMP/keep.txt"

# --- plan-debloat.sh ----------------------------------------------------------------------------
OUT="$(bash "$PLAN_SH" "$TMP/installed.txt" "$TMP/candidates.txt" "$TMP/keep.txt" 2>"$TMP/plan.err")"
rc=$?
expect_rc "plan exits 0" "$rc" 0
expect_line "plan: installed non-kept candidate is DISABLE" "$OUT" "DISABLE com.vendor.ads"
expect_line "plan: trailing comment stripped" "$OUT" "DISABLE com.vendor.news"
expect_line "plan: -f style installed line is matched" "$OUT" "DISABLE com.vendor.tvplus"
expect_line "plan: kept app is KEEP" "$OUT" "KEEP com.vendor.keepme"
expect_line "plan: Google Play services is NEVER" "$OUT" "NEVER com.google.android.gms"
expect_line "plan: Tailscale is NEVER" "$OUT" "NEVER com.tailscale.ipn"
expect_line "plan: uninstalled candidate is ABSENT" "$OUT" "ABSENT com.vendor.notinstalled"
expect_no_line "plan: a package not in the candidate list is never planned" "$OUT" "DISABLE com.vendor.third"
if [ "$(grep -c 'com.vendor.ads' <<<"$OUT")" -eq 1 ]; then ok; else bad "plan: duplicate candidate listed twice"; fi
if grep -qx '# disable=3 keep=1 never=2 absent=1' "$TMP/plan.err"; then ok; else bad "plan: summary line wrong: $(cat "$TMP/plan.err")"; fi

bash "$PLAN_SH" "$TMP/installed.txt" >/dev/null 2>&1; expect_rc "plan: too few args is a usage error" $? 2
bash "$PLAN_SH" "$TMP/nope.txt" "$TMP/candidates.txt" "$TMP/keep.txt" >/dev/null 2>&1; expect_rc "plan: unreadable file is exit 2" $? 2

# Glob entries in the never list work.
printf 'com.vendor.*\n' >"$TMP/never-glob.txt"
OUT="$(bash "$PLAN_SH" "$TMP/installed.txt" "$TMP/candidates.txt" "$TMP/keep.txt" "$TMP/never-glob.txt" 2>/dev/null)"
expect_line "plan: glob never entry refuses com.vendor.ads" "$OUT" "NEVER com.vendor.ads"

# --- stub adb -----------------------------------------------------------------------------------
cat >"$TMP/adb" <<'EOF'
#!/usr/bin/env bash
echo "$*" >>"$STUB_LOG"
case "$*" in
  *"pm disable-user --user 0 "*)
    pkg="${@: -1}"
    if [ "$pkg" = "${STUB_FAIL_PKG:-}" ]; then printf "Exception occurred while executing 'disable-user':\r\n"; exit 0; fi
    printf 'Package %s new state: disabled-user\r\n' "$pkg" ;;
  *"pm list packages -d"*) printf '%s' "${STUB_DISABLED:-}" ;;
esac
EOF
chmod +x "$TMP/adb"
export ADB="$TMP/adb" STUB_LOG="$TMP/adb.log"

printf 'com.vendor.ads\ncom.vendor.news\ncom.vendor.tvplus\n' >"$TMP/batch.txt"
TARGET="100.64.0.9:5555"

# Dry-run (default): prints commands, never calls adb.
: >"$STUB_LOG"
OUT="$(bash "$APPLY_SH" "$TARGET" "$TMP/batch.txt" 2>&1)"; rc=$?
expect_rc "dry-run exits 0" "$rc" 0
if grep -q '^DRY-RUN .*pm disable-user --user 0 com.vendor.ads' <<<"$OUT"; then ok; else bad "dry-run: no DRY-RUN line"; fi
if [ ! -s "$STUB_LOG" ]; then ok; else bad "dry-run must not call adb: $(cat "$STUB_LOG")"; fi

# --apply: disables each package, then syncs.
: >"$STUB_LOG"
OUT="$(bash "$APPLY_SH" --apply --log "$TMP/apply.log" "$TARGET" "$TMP/batch.txt" 2>&1)"; rc=$?
expect_rc "apply exits 0" "$rc" 0
expect_line "apply: OK line per package" "$OUT" "OK com.vendor.news"
if [ "$(grep -c 'pm disable-user --user 0' "$STUB_LOG")" -eq 3 ]; then ok; else bad "apply: expected 3 disable calls"; fi
if grep -qxF -e "-s $TARGET shell sync" "$STUB_LOG"; then ok; else bad "apply: no sync after the batch"; fi
if grep -q 'uninstall\|clear\|reset\|settings put' "$STUB_LOG"; then bad "apply: ran something other than pm disable-user/sync"; else ok; fi
if [ "$(grep -c '^OK ' "$TMP/apply.log")" -eq 3 ]; then ok; else bad "apply: log file missing OK lines"; fi

# --apply stops at the first failure and does not touch later packages.
: >"$STUB_LOG"
STUB_FAIL_PKG=com.vendor.news bash "$APPLY_SH" --apply "$TARGET" "$TMP/batch.txt" >/dev/null 2>&1; rc=$?
expect_rc "apply: failure exits 1" "$rc" 1
if grep -q 'com.vendor.tvplus' "$STUB_LOG"; then bad "apply: continued past a failure"; else ok; fi

# A never-disable package aborts the whole batch BEFORE any disable call.
printf 'com.vendor.ads\ncom.google.android.gms\n' >"$TMP/bad-batch.txt"
: >"$STUB_LOG"
bash "$APPLY_SH" --apply "$TARGET" "$TMP/bad-batch.txt" >/dev/null 2>&1; rc=$?
expect_rc "apply: never-disable package refused" "$rc" 1
if [ ! -s "$STUB_LOG" ]; then ok; else bad "apply: refused batch still called adb"; fi

# Batch size cap.
seq 1 11 | sed 's/^/com.vendor.p/' >"$TMP/big.txt"
bash "$APPLY_SH" --apply "$TARGET" "$TMP/big.txt" >/dev/null 2>&1; expect_rc "apply: 11 packages is over the default cap" $? 2
MAX_BATCH=12 bash "$APPLY_SH" "$TARGET" "$TMP/big.txt" >/dev/null 2>&1; expect_rc "apply: MAX_BATCH override allows it (dry-run)" $? 0

# plan-debloat output can be handed straight over: only DISABLE lines are used.
bash "$PLAN_SH" "$TMP/installed.txt" "$TMP/candidates.txt" "$TMP/keep.txt" >"$TMP/plan-out.txt" 2>/dev/null
: >"$STUB_LOG"
OUT="$(bash "$APPLY_SH" --apply "$TARGET" "$TMP/plan-out.txt" 2>&1)"; rc=$?
expect_rc "apply from plan output exits 0" "$rc" 0
if [ "$(grep -c 'pm disable-user --user 0' "$STUB_LOG")" -eq 3 ]; then ok; else bad "apply from plan: wrong number of disables"; fi

# --verify
export STUB_DISABLED=$'package:com.vendor.ads\r\npackage:com.vendor.news\r\n'
OUT="$(bash "$APPLY_SH" --verify "$TARGET" "$TMP/batch.txt" 2>/dev/null)"; rc=$?
expect_rc "verify: a reverted package exits 1" "$rc" 1
expect_line "verify: reverted package reported" "$OUT" "REVERTED com.vendor.tvplus"
expect_line "verify: surviving package reported" "$OUT" "STILL-DISABLED com.vendor.ads"
export STUB_DISABLED=$'package:com.vendor.ads\npackage:com.vendor.news\npackage:com.vendor.tvplus\n'
bash "$APPLY_SH" --verify "$TARGET" "$TMP/batch.txt" >/dev/null 2>&1; expect_rc "verify: all disabled exits 0" $? 0

# Usage errors.
bash "$APPLY_SH" "$TARGET" >/dev/null 2>&1; expect_rc "apply: missing plan arg is a usage error" $? 2
bash "$APPLY_SH" --bogus "$TARGET" "$TMP/batch.txt" >/dev/null 2>&1; expect_rc "apply: unknown flag is a usage error" $? 2

echo "android-debloat.test.sh: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
