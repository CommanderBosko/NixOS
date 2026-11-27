#!/usr/bin/env bash
# Tests for pull-verify-snapshot.sh. scp is a PATH shim that serves a fixture
# "remote" tree; hosts.json and the backup root are temp fixtures. No network.
# Run: bash .claude/skills/pi-cutover/scripts/pull-verify-snapshot.test.sh
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SH="$HERE/pull-verify-snapshot.sh"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
SHIMS="$TMP/shims"; mkdir -p "$SHIMS"
cat >"$TMP/hosts.json" <<'JSON'
{
  "flakeHosts": ["mypi"],
  "hosts": { "mypi": { "ssh": "bosko@mypi", "tailscaleIp": "100.2.2.2", "flakeHost": true, "arch": "aarch64-linux" } }
}
JSON
export HOSTS_JSON="$TMP/hosts.json" PI_BACKUP_ROOT="$TMP/bk" SHIM_LOG="$TMP/calls.log" REMOTE_ROOT="$TMP/remote"

pass=0 fail=0
ok() { if [ "$2" = "$3" ]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL: $1 -- got '$2', wanted '$3'"; fi; }
has() { case "$2" in *"$3"*) pass=$((pass + 1)) ;; *) fail=$((fail + 1)); echo "FAIL: $1 -- output lacks '$3'"; echo "$2" | head -n 8 ;; esac; }
lacks() { case "$2" in *"$3"*) fail=$((fail + 1)); echo "FAIL: $1 -- output contains '$3'" ;; *) pass=$((pass + 1)) ;; esac; }

absent() { if [ ! -e "$2" ] && [ ! -L "$2" ]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL: $1 -- $2 exists"; fi; }

# scp shim: the last two args are SRC (user@ip:/path) and DEST/. The "remote"
# path is looked up under $REMOTE_ROOT. Fails when SHIM_SCP_FAIL=1.
cat >"$SHIMS/scp" <<'EOS'
#!/usr/bin/env bash
echo "scp $*" >>"$SHIM_LOG"
[ "${SHIM_SCP_FAIL:-0}" = 1 ] && { echo "scp: Permission denied" >&2; exit 1; }
args=("$@"); n=${#args[@]}
src="${args[$((n - 2))]}"; dst="${args[$((n - 1))]}"
path="${src#*:}"
exec cp -a "$REMOTE_ROOT$path" "$dst"
EOS
chmod +x "$SHIMS/scp"
run() { PATH="$SHIMS:$PATH" "$@" 2>&1; }

SENTINEL="TOP-SECRET-SENTINEL-4711"
# mksnap DIR: a good snapshot (JSON + non-JSON + nested) with a valid manifest
mksnap() {
  rm -rf "$1"; mkdir -p "$1/sub"
  printf '{"k":"%s","n":[1,2,3]}\n' "$SENTINEL" >"$1/db.json"
  printf 'plain %s\n' "$SENTINEL" >"$1/sub/notes.txt"
  (cd "$1" && sha256sum db.json sub/notes.txt >SHA256SUMS)
}
reset() { : >"$SHIM_LOG"; rm -rf "$TMP/bk" "$TMP/remote" "$TMP/out"; mkdir -p "$TMP/remote/home/natty"; mksnap "$TMP/remote/home/natty/snap"; mksnap "$TMP/local-snap"; }

# --- usage -----------------------------------------------------------------
out="$(run bash "$SH" --help)"; rc=$?; ok "help exits 0" "$rc" 0; has "help text" "$out" "--remote-dir"
out="$(run bash "$SH")"; rc=$?; ok "no args is a usage error" "$rc" 2
out="$(run bash "$SH" --host mypi)"; rc=$?; ok "missing --remote-dir is a usage error" "$rc" 2
out="$(run bash "$SH" --host mypi --remote-dir "/x y")"; rc=$?; ok "odd remote dir is a usage error" "$rc" 2
out="$(run bash "$SH" --local-src "$TMP/nowhere" --dest "$TMP/o")"; rc=$?; ok "missing local-src is a usage error" "$rc" 2
reset
out="$(run bash "$SH" --local-src "$TMP/local-snap")"; rc=$?; ok "local-src without host or dest is a usage error" "$rc" 2

# --- good snapshot, local source -------------------------------------------
reset
out="$(run bash "$SH" --local-src "$TMP/local-snap" --dest "$TMP/out")"; rc=$?
ok "good snapshot passes the gate" "$rc" 0
has "gate pass line" "$out" "GATE: PASS"
has "file count" "$out" "files: 2"
has "total bytes" "$out" "total bytes: $(( $(stat -c %s "$TMP/local-snap/db.json") + $(stat -c %s "$TMP/local-snap/sub/notes.txt") ))"
has "per-file sha256 (full)" "$out" "$(sha256sum <"$TMP/local-snap/db.json" | cut -d' ' -f1)"
has "json check reported" "$out" "jq empty: 1 JSON"
lacks "never prints file contents" "$out" "$SENTINEL"
ok "dest is 0700" "$(stat -c %a "$TMP/out")" 700
ok "dest holds the files" "$(cmp -s "$TMP/local-snap/db.json" "$TMP/out/db.json" && echo same)" same
ok "no staging dir left behind" "$(find "$TMP" -maxdepth 1 -name '.pull.*' | wc -l)" 0

# --- default destination under the backup dir -------------------------------
reset
out="$(run bash "$SH" --local-src "$TMP/local-snap" --host mypi)"; rc=$?
ok "default dest run passes" "$rc" 0
ok "default dest is under <backup root>/<host>/snapshot-*" "$(find "$TMP/bk/mypi" -maxdepth 1 -name 'snapshot-*' 2>/dev/null | wc -l)" 1
ok "backup host dir is 0700" "$(stat -c %a "$TMP/bk/mypi")" 700

# --- remote pull through the scp shim --------------------------------------
reset
out="$(run bash "$SH" --host mypi --user natty --remote-dir /home/natty/snap --dest "$TMP/out")"; rc=$?
ok "remote pull passes" "$rc" 0; has "gate" "$out" "GATE: PASS"
call="$(cat "$SHIM_LOG")"
has "scp is recursive and BatchMode" "$call" "-r"; has "scp BatchMode" "$call" "BatchMode=yes"
has "scp used the --user override and the tailscale IP" "$call" "natty@100.2.2.2:/home/natty/snap"
lacks "never prints file contents (remote)" "$out" "$SENTINEL"
reset
out="$(run bash "$SH" --host mypi --remote-dir /home/natty/snap --dest "$TMP/out")"; rc=$?
has "default user comes from hosts.json" "$(cat "$SHIM_LOG")" "bosko@100.2.2.2:/home/natty/snap"
reset
out="$(run bash "$SH" --host newpi --ip 100.9.9.9 --remote-dir /home/natty/snap --dest "$TMP/out")"; rc=$?
has "unregistered host works with --ip" "$(cat "$SHIM_LOG")" "bosko@100.9.9.9:"
reset
out="$(run env SHIM_SCP_FAIL=1 bash "$SH" --host mypi --remote-dir /home/natty/snap --dest "$TMP/out")"; rc=$?
ok "scp failure fails" "$rc" 1; has "scp failure message" "$out" "scp failed"
absent "failed pull leaves no dest" "$TMP/out"

# --- gate failures ------------------------------------------------------------
reset; echo "tampered" >>"$TMP/local-snap/sub/notes.txt"
out="$(run bash "$SH" --local-src "$TMP/local-snap" --dest "$TMP/out")"; rc=$?
ok "hash mismatch fails the gate" "$rc" 1; has "gate fail line" "$out" "GATE: FAIL"; has "names the file" "$out" "sub/notes.txt"
has "warns not to power down" "$out" "Do NOT power the Pi down"
lacks "no contents on failure" "$out" "tampered"
reset; printf '{"broken": ' >"$TMP/local-snap/db.json"; (cd "$TMP/local-snap" && sha256sum db.json sub/notes.txt >SHA256SUMS)
out="$(run bash "$SH" --local-src "$TMP/local-snap" --dest "$TMP/out")"; rc=$?
ok "invalid JSON fails the gate" "$rc" 1; has "names the invalid file" "$out" "not valid JSON: db.json"
lacks "jq error text (can quote data) is suppressed" "$out" "parse error"
reset; echo extra >"$TMP/local-snap/unlisted.txt"
out="$(run bash "$SH" --local-src "$TMP/local-snap" --dest "$TMP/out")"; rc=$?
ok "an unlisted file fails the gate" "$rc" 1; has "names it" "$out" "not in SHA256SUMS: unlisted.txt"
reset; rm "$TMP/local-snap/sub/notes.txt"
out="$(run bash "$SH" --local-src "$TMP/local-snap" --dest "$TMP/out")"; rc=$?
ok "a missing listed file fails the gate" "$rc" 1; has "names it" "$out" "missing: sub/notes.txt"
reset; rm "$TMP/local-snap/SHA256SUMS"
out="$(run bash "$SH" --local-src "$TMP/local-snap" --dest "$TMP/out")"; rc=$?
ok "no SHA256SUMS fails the gate" "$rc" 1
reset; rm -rf "$TMP/local-snap"; mkdir "$TMP/local-snap"; : >"$TMP/local-snap/SHA256SUMS"
out="$(run bash "$SH" --local-src "$TMP/local-snap" --dest "$TMP/out")"; rc=$?
ok "an empty snapshot fails the gate" "$rc" 1

# --- never overwrite ------------------------------------------------------------
reset; mkdir -p "$TMP/out"; echo old >"$TMP/out/keep"
out="$(run bash "$SH" --local-src "$TMP/local-snap" --dest "$TMP/out")"; rc=$?
ok "non-empty dest is refused" "$rc" 1; ok "existing dest untouched" "$(cat "$TMP/out/keep")" old

echo "pull-verify-snapshot.test.sh: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
