#!/usr/bin/env bash
# Tests for restore-on-pi.sh. id, systemctl and curl are PATH shims that log
# their calls (nothing real is stopped or started); install/mv/sha256sum are
# real, run against fixtures in a temp dir and owned by the current user.
# Run: bash .claude/skills/pi-cutover/scripts/on-pi/restore-on-pi.test.sh
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SH="$HERE/restore-on-pi.sh"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
SHIMS="$TMP/shims"; mkdir -p "$SHIMS" "$TMP/units"
export SHIM_LOG="$TMP/calls.log" SHIM_UNITS="$TMP/units"
REAL_ID="$(command -v id)"; export REAL_ID
ME="$(id -un)"; MYGROUP="$(id -gn)"; OWN="$ME:$MYGROUP"

pass=0 fail=0
ok() { if [ "$2" = "$3" ]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL: $1 -- got '$2', wanted '$3'"; fi; }
has() { case "$2" in *"$3"*) pass=$((pass + 1)) ;; *) fail=$((fail + 1)); echo "FAIL: $1 -- output lacks '$3'"; echo "$2" | head -n 8 ;; esac; }
lacks() { case "$2" in *"$3"*) fail=$((fail + 1)); echo "FAIL: $1 -- output contains '$3'" ;; *) pass=$((pass + 1)) ;; esac; }
log_has() { if grep -qF -- "$2" "$SHIM_LOG" 2>/dev/null; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL: $1 -- call log lacks '$2'"; fi; }
absent() { if [ ! -e "$2" ] && [ ! -L "$2" ]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL: $1 -- $2 exists"; fi; }
log_lacks() { if grep -qF -- "$2" "$SHIM_LOG" 2>/dev/null; then fail=$((fail + 1)); echo "FAIL: $1 -- call log has '$2'"; else pass=$((pass + 1)); fi; }

cat >"$SHIMS/id" <<'EOS'
#!/usr/bin/env bash
if [ "$#" -eq 1 ] && [ "$1" = "-u" ]; then echo "${SHIM_UID:-0}"; exit 0; fi
exec "$REAL_ID" "$@"
EOS
cat >"$SHIMS/systemctl" <<'EOS'
#!/usr/bin/env bash
echo "systemctl $*" >>"$SHIM_LOG"
case "$1" in
  is-active) [ -e "$SHIM_UNITS/${@: -1}" ]; exit $? ;;
  stop) rm -f "$SHIM_UNITS/$2"; exit 0 ;;
  start) [ "${SHIM_NOSTART:-0}" = 1 ] || touch "$SHIM_UNITS/$2"; exit 0 ;;
esac
exit 0
EOS
cat >"$SHIMS/curl" <<'EOS'
#!/usr/bin/env bash
echo "curl $*" >>"$SHIM_LOG"
printf '%s' "${SHIM_HTTP:-200}"
[ "${SHIM_HTTP:-200}" != 000 ]
EOS
cat >"$SHIMS/install" <<'EOS'
#!/usr/bin/env bash
if [ "${SHIM_INSTALL_FAIL:-0}" = 1 ]; then n="$(cat "$SHIM_UNITS/.n" 2>/dev/null || echo 0)"; echo $((n + 1)) >"$SHIM_UNITS/.n"; [ "$n" -ge 1 ] && { echo "install: simulated failure" >&2; exit 1; }; fi
exec "$REAL_INSTALL" "$@"
EOS
chmod +x "$SHIMS"/*
REAL_INSTALL="$(command -v install)"; export REAL_INSTALL

SENTINEL="TOP-SECRET-SENTINEL-4711"
reset() {
  : >"$SHIM_LOG"; rm -rf "$TMP/units" "$TMP/state" "$TMP/src"; mkdir -p "$TMP/units" "$TMP/state" "$TMP/src"
  touch "$TMP/units/myapp"
  printf '{"fresh":true}\n' >"$TMP/state/db.json"           # what the new node created itself
  printf '{"snap":"%s"}\n' "$SENTINEL" >"$TMP/src/db.json"  # what the snapshot carries
  printf 'extra %s\n' "$SENTINEL" >"$TMP/src/extra.txt"
}
run() { PATH="$SHIMS:$PATH" "$@" 2>&1; }
BASE=(--unit myapp --owner "$OWN")

# --- usage ---------------------------------------------------------------
out="$(run bash "$SH" --help)"; rc=$?; ok "help exits 0" "$rc" 0; has "help text" "$out" "--src FILE"
out="$(run bash "$SH")"; rc=$?; ok "no args is a usage error" "$rc" 2
reset
out="$(run bash "$SH" --unit myapp --state-dir "$TMP/state")"; rc=$?; ok "missing --src is a usage error" "$rc" 2
out="$(run bash "$SH" --unit myapp --state-dir "$TMP/state" --src)"; rc=$?; ok "--src without a file is a usage error" "$rc" 2
out="$(run bash "$SH" "${BASE[@]}" --state-dir "$TMP/state" --src "$TMP/src/db.json" --mode 99)"; rc=$?; ok "bad mode is a usage error" "$rc" 2
out="$(run bash "$SH" "${BASE[@]}" --state-dir "$TMP/state" --src "$TMP/src/db.json" --url ftp://x)"; rc=$?; ok "non-http url is a usage error" "$rc" 2
out="$(run bash "$SH" "${BASE[@]}" --state-dir "$TMP/missing" --src "$TMP/src/db.json")"; rc=$?; ok "missing state dir is refused" "$rc" 1
out="$(run bash "$SH" "${BASE[@]}" --state-dir "$TMP/state" --src "$TMP/src/nope.json")"; rc=$?; ok "missing source is refused" "$rc" 1
log_lacks "refusals changed nothing" "systemctl stop"

# --- dry run (real uid, no root) -----------------------------------------
if [ "$(id -u)" -ne 0 ]; then
  reset
  out="$(PATH="$SHIMS:$PATH" bash "$SH" "${BASE[@]}" --state-dir "$TMP/state" --src "$TMP/src/db.json" "$TMP/src/extra.txt" --url http://127.0.0.1:3000/ --dry-run 2>&1)"; rc=$?
  ok "dry-run needs no root" "$rc" 0
  has "dry-run banner" "$out" "DRY RUN"; has "plans an aside move" "$out" ".pre-restore-"; has "plans the curl" "$out" "curl -sS"
  ok "dry-run left the target alone" "$(cat "$TMP/state/db.json")" '{"fresh":true}'
  absent "dry-run installed nothing" "$TMP/state/extra.txt"
  log_lacks "dry-run called no shim" "systemctl"
  out="$(run env SHIM_UID=1000 bash "$SH" "${BASE[@]}" --state-dir "$TMP/state" --src "$TMP/src/db.json")"; rc=$?
  ok "real run without root is refused" "$rc" 1; has "root message" "$out" "must run as root"
  ok "refused run left the target alone" "$(cat "$TMP/state/db.json")" '{"fresh":true}'
fi

# --- real run ---------------------------------------------------------------
reset
out="$(run bash "$SH" "${BASE[@]}" --state-dir "$TMP/state" --src "$TMP/src/db.json" "$TMP/src/extra.txt" --url http://127.0.0.1:3000/?token=TOKENSENTINEL)"; rc=$?
ok "restore exits 0" "$rc" 0
ok "db.json is the snapshot's" "$(cmp -s "$TMP/src/db.json" "$TMP/state/db.json" && echo same)" same
ok "extra.txt installed" "$(cmp -s "$TMP/src/extra.txt" "$TMP/state/extra.txt" && echo same)" same
ok "mode defaults to 0600" "$(stat -c %a "$TMP/state/db.json")" 600
ok "owner applied" "$(stat -c %U:%G "$TMP/state/db.json")" "$OWN"
aside="$(find "$TMP/state" -maxdepth 1 -name 'db.json.pre-restore-*' | head -n1)"
ok "old db.json kept as .pre-restore-<stamp>" "$([ -n "$aside" ] && echo yes)" yes
ok "aside holds the old content" "$(cat "$aside")" '{"fresh":true}'
ok "no aside for a file that did not exist" "$(find "$TMP/state" -maxdepth 1 -name 'extra.txt.pre-restore-*' | wc -l)" 0
has "stamp is UTC-shaped" "$aside" ".pre-restore-20"
has "reports unit active" "$out" "myapp: active"
has "reports url pass" "$out" "HTTP 200"
lacks "token in the url is not echoed" "$out" "TOKENSENTINEL"
lacks "never prints file contents" "$out" "$SENTINEL"
has "prints a hash prefix" "$out" "$(sha256sum <"$TMP/src/db.json" | cut -c1-16)"
log_has "stopped the unit" "systemctl stop myapp"; log_has "started the unit" "systemctl start myapp"
ok "stop comes before start" "$(grep -E 'systemctl (stop|start)' "$SHIM_LOG" | tr '\n' ',')" "systemctl stop myapp,systemctl start myapp,"
log_has "curl checked the url" "curl -sS -m 10 -o /dev/null -w %{http_code} http://127.0.0.1:3000/?token=TOKENSENTINEL"

# --- mode and owner defaults ------------------------------------------------
reset
out="$(run bash "$SH" --unit myapp --state-dir "$TMP/state" --src "$TMP/src/db.json" --mode 0640)"; rc=$?
ok "owner defaults to the state dir's owner (rc)" "$rc" 0
ok "custom mode" "$(stat -c %a "$TMP/state/db.json")" 640

# --- failures -----------------------------------------------------------------
reset
out="$(run env SHIM_NOSTART=1 bash "$SH" "${BASE[@]}" --state-dir "$TMP/state" --src "$TMP/src/db.json" --wait 1)"; rc=$?
ok "unit that never goes active fails" "$rc" 1
has "says so" "$out" "not active"; has "tells how to undo" "$out" "STILL IN PLACE"
ok "restored files stay in place after an app failure" "$(cmp -s "$TMP/src/db.json" "$TMP/state/db.json" && echo same)" same
reset
out="$(run env SHIM_HTTP=503 bash "$SH" "${BASE[@]}" --state-dir "$TMP/state" --src "$TMP/src/db.json" --url http://127.0.0.1:3000/ --wait 1)"; rc=$?
ok "bad http status fails" "$rc" 1; has "reports the status" "$out" "503"
reset
out="$(run env SHIM_HTTP=000 bash "$SH" "${BASE[@]}" --state-dir "$TMP/state" --src "$TMP/src/db.json" --url http://127.0.0.1:3000/ --wait 1)"; rc=$?
ok "unreachable url fails" "$rc" 1
reset
out="$(run env SHIM_INSTALL_FAIL=1 bash "$SH" "${BASE[@]}" --state-dir "$TMP/state" --src "$TMP/src/db.json" "$TMP/src/extra.txt")"; rc=$?
ok "install failure exits non-zero" "$rc" 1
has "rolls back" "$out" "ROLLING BACK"
ok "original db.json is back after the rollback" "$(cat "$TMP/state/db.json")" '{"fresh":true}'
ok "no pre-restore leftovers after the rollback" "$(find "$TMP/state" -mindepth 1 -maxdepth 1 -printf '%f\n' | sort | tr '\n' ' ')" "db.json "
log_has "rollback restarted the unit" "systemctl start myapp"
reset; rm -f "$TMP/units/myapp"
out="$(run env SHIM_INSTALL_FAIL=1 bash "$SH" "${BASE[@]}" --state-dir "$TMP/state" --src "$TMP/src/db.json" "$TMP/src/extra.txt")"; rc=$?
log_lacks "a unit that was not running is not restarted by the rollback" "systemctl start"

echo "restore-on-pi.test.sh: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
