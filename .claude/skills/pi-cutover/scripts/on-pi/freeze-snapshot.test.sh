#!/usr/bin/env bash
# Tests for freeze-snapshot.sh. Everything privileged is a PATH shim (id,
# systemctl, shutdown, chown, cp) that logs its call; the files are fixtures in
# a temp dir. Nothing real is stopped, owned or powered off.
# Run: bash .claude/skills/pi-cutover/scripts/on-pi/freeze-snapshot.test.sh
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SH="$HERE/freeze-snapshot.sh"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
SHIMS="$TMP/shims"; mkdir -p "$SHIMS" "$TMP/units"
export SHIM_LOG="$TMP/calls.log" SHIM_UNITS="$TMP/units"
REAL_ID="$(command -v id)"; REAL_CP="$(command -v cp)"; export REAL_ID REAL_CP
ME="$(id -un)"

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
  start) touch "$SHIM_UNITS/$2"; exit 0 ;;
esac
exit 0
EOS
cat >"$SHIMS/shutdown" <<'EOS'
#!/usr/bin/env bash
echo "shutdown $*" >>"$SHIM_LOG"
EOS
cat >"$SHIMS/chown" <<'EOS'
#!/usr/bin/env bash
echo "chown $*" >>"$SHIM_LOG"
EOS
cat >"$SHIMS/cp" <<'EOS'
#!/usr/bin/env bash
if [ "${SHIM_CP_FAIL:-0}" = 1 ]; then echo "cp: simulated failure" >&2; exit 1; fi
exec "$REAL_CP" "$@"
EOS
chmod +x "$SHIMS"/*

SENTINEL="TOP-SECRET-SENTINEL-4711"
mkstate() { # dir  -> a state dir with a nested tree; the sentinel is only inside files
  mkdir -p "$1/sub"
  printf '{"k":"%s"}\n' "$SENTINEL" >"$1/db.json"
  printf 'x%s\n' "$SENTINEL" >"$1/sub/notes.txt"
  printf 'plain\n' >"$1/sub/other.bin"
}
reset() { : >"$SHIM_LOG"; rm -f "$TMP"/units/*; touch "$TMP/units/myapp"; rm -rf "$TMP/state" "$TMP/out"; mkstate "$TMP/state"; mkdir -p "$TMP/snaps"; rm -rf "$TMP/snaps/s1"; }
run() { PATH="$SHIMS:$PATH" "$@" 2>&1; }

# --- usage ---------------------------------------------------------------
out="$(run bash "$SH" --help)"; rc=$?
ok "help exits 0" "$rc" 0; has "help text" "$out" "--dry-run"
out="$(run bash "$SH")"; rc=$?; ok "no args is a usage error" "$rc" 2
out="$(run bash "$SH" --bogus)"; rc=$?; ok "unknown flag is a usage error" "$rc" 2
reset
out="$(run bash "$SH" --unit myapp --state-dir "$TMP/state" --dest "$TMP/snaps/s1" --owner "$ME" --shutdown-minutes 0)"; rc=$?
ok "minutes 0 is a usage error" "$rc" 2
out="$(run bash "$SH" --unit myapp --state-dir relative/dir --dest "$TMP/snaps/s1" --owner "$ME")"; rc=$?
ok "relative state dir is a usage error" "$rc" 2
out="$(run bash "$SH" --unit myapp --state-dir "$TMP/state" --dest "$TMP/snaps/s1" --owner root)"; rc=$?
ok "owner root is refused" "$rc" 2
out="$(env -u SUDO_USER PATH="$SHIMS:$PATH" bash "$SH" --unit myapp --state-dir "$TMP/state" --dest "$TMP/snaps/s1" --no-shutdown 2>&1)"; rc=$?
ok "no owner and no SUDO_USER is refused" "$rc" 2; has "owner message" "$out" "SUDO_USER"
log_lacks "refusal touched nothing" "systemctl"

# --- dry run: no root, no changes ----------------------------------------
if [ "$(id -u)" -ne 0 ]; then
  reset
  out="$(PATH="$SHIMS:$PATH" bash "$SH" --unit myapp --state-dir "$TMP/state" --dest "$TMP/snaps/s1" --owner "$ME" --dry-run 2>&1)"; rc=$?
  ok "dry-run needs no root (real uid)" "$rc" 0
  has "dry-run banner" "$out" "DRY RUN"
  has "dry-run plans the stop" "$out" "systemctl stop myapp"
  has "dry-run plans the shutdown" "$out" "shutdown -h +1"
  absent "dry-run created nothing" "$TMP/snaps/s1"
  log_lacks "dry-run called no shim" "systemctl"
  out="$(run env SHIM_UID=1000 bash "$SH" --unit myapp --state-dir "$TMP/state" --dest "$TMP/snaps/s1" --owner "$ME" --no-shutdown)"; rc=$?
  ok "real run without root is refused" "$rc" 1; has "root message" "$out" "must run as root"
  absent "refused run created nothing" "$TMP/snaps/s1"
  log_lacks "refused run stopped nothing" "systemctl stop"
fi

# --- real run with --no-shutdown -----------------------------------------
reset
out="$(run bash "$SH" --unit myapp --state-dir "$TMP/state" --dest "$TMP/snaps/s1" --owner "$ME" --no-shutdown)"; rc=$?
ok "run exits 0" "$rc" 0
has "reports the file count" "$out" "snapshot: 3 files"
has "reports it is verified" "$out" "verified"
lacks "never prints file contents" "$out" "$SENTINEL"
log_has "stopped the unit" "systemctl stop myapp"
log_lacks "no shutdown with --no-shutdown" "shutdown"
log_has "chowned the snapshot to the owner" "chown -R $ME: $TMP/snaps/s1"
ok "snapshot dir is 0700" "$(stat -c %a "$TMP/snaps/s1")" 700
(cd "$TMP/snaps/s1" && sha256sum --quiet -c SHA256SUMS) >/dev/null 2>&1; ok "SHA256SUMS verifies" "$?" 0
ok "SHA256SUMS lists 3 relative paths" "$(grep -c '^[0-9a-f]\{64\}  [^/.]' "$TMP/snaps/s1/SHA256SUMS")" 3
ok "nested file copied" "$(cmp -s "$TMP/state/sub/notes.txt" "$TMP/snaps/s1/sub/notes.txt" && echo same)" same
ok "stop is the first systemctl call after the is-active probe" "$(grep -v is-active "$SHIM_LOG" | head -n1)" "systemctl stop myapp"

# --- shutdown scheduling --------------------------------------------------
reset
out="$(run bash "$SH" --unit myapp --state-dir "$TMP/state" --dest "$TMP/snaps/s1" --owner "$ME")"; rc=$?
ok "default run exits 0" "$rc" 0
log_has "default shutdown is +1" "shutdown -h +1"
has "tells how to cancel" "$out" "shutdown -c"
reset
out="$(run bash "$SH" --unit myapp --state-dir "$TMP/state" --dest "$TMP/snaps/s1" --owner "$ME" --shutdown-minutes 7)"; rc=$?
log_has "custom minutes" "shutdown -h +7"
reset
out="$(env SUDO_USER="$ME" PATH="$SHIMS:$PATH" bash "$SH" --unit myapp --state-dir "$TMP/state" --dest "$TMP/snaps/s1" --no-shutdown 2>&1)"; rc=$?
ok "SUDO_USER is the default owner" "$rc" 0
log_has "chown used SUDO_USER" "chown -R $ME: "

# --- several units --------------------------------------------------------
reset; touch "$TMP/units/other"
out="$(run bash "$SH" --unit myapp --unit other --state-dir "$TMP/state" --dest "$TMP/snaps/s1" --owner "$ME" --no-shutdown)"; rc=$?
ok "two units: exits 0" "$rc" 0
log_has "first unit stopped" "systemctl stop myapp"; log_has "second unit stopped" "systemctl stop other"

# --- failure after the stop restarts the unit ------------------------------
reset
out="$(run env SHIM_CP_FAIL=1 bash "$SH" --unit myapp --state-dir "$TMP/state" --dest "$TMP/snaps/s1" --owner "$ME")"; rc=$?
ok "copy failure exits non-zero" "$rc" 1
log_has "unit stopped before the failure" "systemctl stop myapp"
log_has "unit started again after the failure" "systemctl start myapp"
log_lacks "no shutdown after a failed copy" "shutdown"
has "says it restarted" "$out" "starting it again"
reset; rm -f "$TMP/units/myapp"
out="$(run env SHIM_CP_FAIL=1 bash "$SH" --unit myapp --state-dir "$TMP/state" --dest "$TMP/snaps/s1" --owner "$ME")"; rc=$?
ok "failure with a unit that was not running exits non-zero" "$rc" 1
log_lacks "a unit that was not running is not started" "systemctl start"
reset; rm -rf "$TMP/state"; mkdir -p "$TMP/state"
out="$(run bash "$SH" --unit myapp --state-dir "$TMP/state" --dest "$TMP/snaps/s1" --owner "$ME" --no-shutdown)"; rc=$?
ok "empty state dir is refused" "$rc" 1; log_has "empty state dir: unit restarted" "systemctl start myapp"

# --- refusals that change nothing -------------------------------------------
reset; mkdir -p "$TMP/snaps/s1"; echo old >"$TMP/snaps/s1/keep"
out="$(run bash "$SH" --unit myapp --state-dir "$TMP/state" --dest "$TMP/snaps/s1" --owner "$ME")"; rc=$?
ok "non-empty dest is refused" "$rc" 1; log_lacks "non-empty dest: nothing stopped" "systemctl stop"
ok "existing dest untouched" "$(cat "$TMP/snaps/s1/keep")" old
reset
out="$(run bash "$SH" --unit myapp --state-dir "$TMP/state" --dest "$TMP/state/snap" --owner "$ME")"; rc=$?
ok "dest inside state dir is refused" "$rc" 1; log_lacks "dest inside state: nothing stopped" "systemctl stop"
reset
out="$(run bash "$SH" --unit myapp --state-dir "$TMP/state" --dest "$TMP/no-such-parent/s1" --owner "$ME")"; rc=$?
ok "missing dest parent is refused" "$rc" 1
reset; : >"$TMP/state/SHA256SUMS"
out="$(run bash "$SH" --unit myapp --state-dir "$TMP/state" --dest "$TMP/snaps/s1" --owner "$ME")"; rc=$?
ok "state dir with its own SHA256SUMS is refused" "$rc" 1; log_lacks "own-manifest refusal: nothing stopped" "systemctl stop"

echo "freeze-snapshot.test.sh: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
