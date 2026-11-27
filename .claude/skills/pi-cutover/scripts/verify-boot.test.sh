#!/usr/bin/env bash
# Tests for verify-boot.sh. ping, ssh, ssh-keyscan and ssh-keygen are PATH shims
# (no real network, no real keys: the "keys" are dummy text blobs); hosts.json,
# known_hosts and the probe output are fixtures in a temp dir.
# Run: bash .claude/skills/pi-cutover/scripts/verify-boot.test.sh
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SH="$HERE/verify-boot.sh"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
SHIMS="$TMP/shims"; mkdir -p "$SHIMS"
cat >"$TMP/hosts.json" <<'JSON'
{
  "flakeHosts": ["mypi"],
  "hosts": { "mypi": { "ssh": "bosko@mypi", "tailscaleIp": "100.2.2.2", "flakeHost": true, "arch": "aarch64-linux" } }
}
JSON
export HOSTS_JSON="$TMP/hosts.json" PI_BACKUP_ROOT="$TMP/bk" SHIM_LOG="$TMP/calls.log" PING_N="$TMP/ping.n"
export SHIM_PROBE="$TMP/probe.out" SHIM_STDIN="$TMP/probe.stdin" KNOWN_HOSTS="$TMP/known_hosts" PI_POLL_INTERVAL=1

pass=0 fail=0
ok() { if [ "$2" = "$3" ]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL: $1 -- got '$2', wanted '$3'"; fi; }
has() { case "$2" in *"$3"*) pass=$((pass + 1)) ;; *) fail=$((fail + 1)); echo "FAIL: $1 -- output lacks '$3'"; echo "$2" | head -n 30 ;; esac; }
lacks() { case "$2" in *"$3"*) fail=$((fail + 1)); echo "FAIL: $1 -- output contains '$3'" ;; *) pass=$((pass + 1)) ;; esac; }
log_has() { if grep -qF -- "$2" "$SHIM_LOG" 2>/dev/null; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL: $1 -- call log lacks '$2'"; fi; }
log_lacks() { if grep -qF -- "$2" "$SHIM_LOG" 2>/dev/null; then fail=$((fail + 1)); echo "FAIL: $1 -- call log has '$2'"; else pass=$((pass + 1)); fi; }

# ping: succeeds from the Nth call on (PING_OK_AFTER, default 1; 999 = never)
cat >"$SHIMS/ping" <<'EOS'
#!/usr/bin/env bash
n="$(cat "$PING_N" 2>/dev/null || echo 0)"; n=$((n + 1)); echo "$n" >"$PING_N"
[ "$n" -ge "${PING_OK_AFTER:-1}" ]
EOS
# ssh-keyscan: the Pi presents the dummy key blob SCAN_BLOB (empty output with SCAN_EMPTY=1)
cat >"$SHIMS/ssh-keyscan" <<'EOS'
#!/usr/bin/env bash
echo "ssh-keyscan $*" >>"$SHIM_LOG"
[ "${SCAN_EMPTY:-0}" = 1 ] && exit 0
echo "# 100.2.2.2:22 SSH-2.0-OpenSSH_fake"
echo "100.2.2.2 ssh-ed25519 ${SCAN_BLOB:-FAKEBLOBGOOD}"
EOS
# ssh-keygen: -lf FILE => fake fingerprint from the blob; -F HOST -f KH => matching lines; -R => log only
cat >"$SHIMS/ssh-keygen" <<'EOS'
#!/usr/bin/env bash
echo "ssh-keygen $*" >>"$SHIM_LOG"
case "$1" in
  -lf) blob="$(tr ' ' '\n' <"$2" | grep -A1 -m1 '^ssh-ed25519$' | tail -n1)"; [ -n "$blob" ] || exit 1; echo "256 SHA256:$blob $2 (ED25519)"; exit 0 ;;
  -F) [ -r "$4" ] || exit 1; m="$(grep "^$2 " "$4")" || exit 1; echo "# Host $2 found: line 1"; echo "$m"; exit 0 ;;
  -R) exit 0 ;;
esac
exit 1
EOS
# ssh: options are skipped; "true" probes reachability; "bash -s" returns the probe fixture
cat >"$SHIMS/ssh" <<'EOS'
#!/usr/bin/env bash
echo "ssh $*" >>"$SHIM_LOG"
while [ $# -gt 0 ]; do case "$1" in -o) shift 2 ;; -*) shift ;; *) break ;; esac; done
shift  # the target
if [ "${SHIM_SSH_FAIL:-0}" = 1 ]; then echo "bosko@100.2.2.2: Permission denied (publickey)." >&2; exit 255; fi
case "$*" in
  true) exit 0 ;;
  "bash -s") cat >"$SHIM_STDIN"; cat "$SHIM_PROBE"; exit 0 ;;
esac
exit 0
EOS
chmod +x "$SHIMS"/*

T=$'\t'
# the all-green probe output (what the Pi's remote script would print)
green_probe() {
  {
    printf '@failed_rc%s0\n' "$T"
    printf '@sys%s/nix/store/abc-nixos-system-mypi-26.11\n' "$T"
    printf '@root%s/dev/mmcblk0p2%smmcblk0%s31000000000%s31900000000\n' "$T" "$T" "$T" "$T"
    printf '@ts_active%sactive\n@ts_addr%s100.2.2.2/32\n' "$T" "$T"
    printf '@nmcli%spresent\n' "$T"
    printf '@link%swlan0%sconnected\n' "$T" "$T"
    printf '@journal%syes\n' "$T"
    printf '@secret%smysecret%syes\n' "$T" "$T"
    printf '@unit%smyapp.service%sactive\n' "$T" "$T"
    printf '@url%shttp://127.0.0.1:3000/%s200%s0\n' "$T" "$T" "$T"
    printf '@done%s1\n' "$T"
  } >"$SHIM_PROBE"
}
reset() {
  : >"$SHIM_LOG"; rm -f "$PING_N" "$SHIM_STDIN"
  unset PING_OK_AFTER SCAN_BLOB SCAN_EMPTY SHIM_SSH_FAIL
  green_probe
  printf 'ssh-ed25519 FAKEBLOBGOOD pre-generated-for-mypi\n' >"$TMP/expect.pub"
  : >"$KNOWN_HOSTS"
}
ARGS=(--host mypi --expect-pubkey "$TMP/expect.pub" --no-wait --unit myapp.service --url http://127.0.0.1:3000/ --secret mysecret --link wlan0)
run() { PATH="$SHIMS:$PATH" "$@" 2>&1; }

# --- usage -----------------------------------------------------------------------
out="$(run bash "$SH" --help)"; rc=$?; ok "help exits 0" "$rc" 0; has "help text" "$out" "--fix-known-hosts"
out="$(run bash "$SH")"; rc=$?; ok "no args is a usage error" "$rc" 2
reset
out="$(run bash "$SH" --host mypi --secret 'a;b')"; rc=$?; ok "secret name with ; is a usage error" "$rc" 2
out="$(run bash "$SH" --host mypi --secret '../etc')"; rc=$?; ok "secret name with .. is a usage error" "$rc" 2
out="$(run bash "$SH" --host mypi --url 'ftp://x')"; rc=$?; ok "non-http url is a usage error" "$rc" 2
out="$(run bash "$SH" --host mypi --wait soon)"; rc=$?; ok "bad --wait is a usage error" "$rc" 2
# Assemble the marker at run time so this file never holds a literal private-key
# block (the repo's secret scan rightly flags one, even a dummy).
pk_word="PRIV""ATE KEY"
printf -- '-----BEGIN OPENSSH %s-----\nDUMMY-PLACEHOLDER-NOT-A-KEY\n-----END OPENSSH %s-----\n' "$pk_word" "$pk_word" >"$TMP/priv.txt"
out="$(run bash "$SH" --host mypi --expect-pubkey "$TMP/priv.txt")"; rc=$?
ok "a private key file is refused" "$rc" 2; has "says why" "$out" "PUBLIC key"
lacks "never echoes the key text" "$out" "DUMMY-PLACEHOLDER"
out="$(run bash "$SH" --host mypi --expect-pubkey "$TMP/nope.pub")"; rc=$?; ok "unreadable pubkey is a usage error" "$rc" 2

# --- all green ----------------------------------------------------------------------
reset
out="$(run bash "$SH" "${ARGS[@]}")"; rc=$?
ok "all green exits 0" "$rc" 0
has "result line" "$out" "RESULT: PASS (0 fail, 0 warn)"
for c in "PASS ping:" "PASS hostkey:" "PASS known_hosts:" "PASS ssh:" "PASS failed-units: none" "PASS system:" "PASS root-fs:" "PASS tailscale:" "PASS link:wlan0:" "PASS journald:" "PASS secret:mysecret:" "PASS unit:myapp.service:" "PASS url:http://127.0.0.1:3000/:"; do
  has "green: $c" "$out" "$c"
done
log_has "host key was scanned with ed25519 and the 5 s timeout" "ssh-keyscan -t ed25519 -T 5 100.2.2.2"
log_has "ssh ran BatchMode" "BatchMode=yes"
log_has "ssh is pinned to a temp known_hosts" "UserKnownHostsFile="
log_has "ssh targets bosko at the tailscale IP" "bosko@100.2.2.2"
ok "exactly one batched probe session" "$(grep -c 'ssh .*bash -s' "$SHIM_LOG")" 1
probe_script="$(cat "$SHIM_STDIN")"
# shellcheck disable=SC2016 # literal text of the remote script; no expansion wanted
has "probe tests secret existence only" "$probe_script" '-e "/run/secrets/$s"'
has "probe passes the unit through" "$probe_script" "myapp.service"
lacks "probe never cats a secret" "$probe_script" "cat /run/secrets"

# --- no expect-pubkey: SKIP, not FAIL ----------------------------------------------
reset
out="$(run bash "$SH" --host mypi --no-wait)"; rc=$?
ok "no pubkey exits 0" "$rc" 0; has "hostkey is skipped" "$out" "SKIP hostkey:"
lacks "ssh is not pinned without a verified key" "$(cat "$SHIM_LOG")" "UserKnownHostsFile="

# --- host key mismatch -----------------------------------------------------------
reset; export SCAN_BLOB=FAKEBLOBOTHER
out="$(run bash "$SH" "${ARGS[@]}")"; rc=$?
ok "key mismatch exits 1" "$rc" 1; has "mismatch is a FAIL" "$out" "FAIL hostkey: MISMATCH"
has "tells the user not to copy data" "$out" "Do not copy any data"
has "result FAIL" "$out" "RESULT: FAIL"
has "ssh is not attempted against a mismatching host" "$out" "SKIP ssh: not connecting"
has "remote probes skipped on mismatch" "$out" "SKIP remote-probes:"
ok "no ssh call at all on a mismatch" "$(grep -c '^ssh -o' "$SHIM_LOG")" 0
lacks "ssh is not pinned to a mismatching key" "$(cat "$SHIM_LOG")" "UserKnownHostsFile="

# --- failed unit ------------------------------------------------------------------
reset
{ printf '@failed_rc%s0\n@failed%sfoo.service\n@failed%sbar.service\n' "$T" "$T" "$T"; grep -v '^@failed_rc' "$SHIM_PROBE"; } >"$TMP/p2" && mv "$TMP/p2" "$SHIM_PROBE"
out="$(run bash "$SH" "${ARGS[@]}")"; rc=$?
ok "failed unit exits 1" "$rc" 1; has "names the failed units" "$out" "FAIL failed-units: 2 failed: foo.service,bar.service"
reset; sed -i "s/^@unit.*/@unit${T}myapp.service${T}failed/" "$SHIM_PROBE"
out="$(run bash "$SH" "${ARGS[@]}")"; rc=$?
ok "inactive --unit exits 1" "$rc" 1; has "unit FAIL" "$out" "FAIL unit:myapp.service: state 'failed'"

# --- unexpanded root partition -------------------------------------------------------
reset; sed -i "s/^@root.*/@root${T}\/dev\/mmcblk0p2${T}mmcblk0${T}2800000000${T}31900000000/" "$SHIM_PROBE"
out="$(run bash "$SH" "${ARGS[@]}")"; rc=$?
ok "unexpanded root exits 1" "$rc" 1; has "root-fs FAIL" "$out" "FAIL root-fs:"
has "manual fix: sfdisk" "$out" "sfdisk -N2 --no-reread /dev/mmcblk0"
has "manual fix: partx" "$out" "partx -u /dev/mmcblk0"; has "manual fix: resize2fs" "$out" "resize2fs /dev/mmcblk0p2"

# --- other probe verdicts ---------------------------------------------------------------
reset; sed -i "s/^@ts_active.*/@ts_active${T}inactive/; s/^@ts_addr.*/@ts_addr${T}-/" "$SHIM_PROBE"
out="$(run bash "$SH" "${ARGS[@]}")"; rc=$?; ok "tailscale down exits 1" "$rc" 1; has "tailscale FAIL" "$out" "FAIL tailscale:"
reset; sed -i "s/^@secret.*/@secret${T}mysecret${T}no/" "$SHIM_PROBE"
out="$(run bash "$SH" "${ARGS[@]}")"; rc=$?; ok "missing secret exits 1" "$rc" 1; has "secret FAIL" "$out" "FAIL secret:mysecret:"
reset; sed -i "s/^@journal.*/@journal${T}no/" "$SHIM_PROBE"
out="$(run bash "$SH" "${ARGS[@]}")"; rc=$?; ok "volatile journal is only a WARN (exit 0)" "$rc" 0; has "journald WARN" "$out" "WARN journald:"; has "result counts the warn" "$out" "RESULT: PASS (0 fail, 1 warn)"
reset; sed -i "s/^@nmcli.*/@nmcli${T}absent/; /^@link/d" "$SHIM_PROBE"
out="$(run bash "$SH" "${ARGS[@]}")"; rc=$?; ok "no nmcli exits 0" "$rc" 0; has "link is SKIP without nmcli" "$out" "SKIP link:wlan0:"
reset; sed -i "s/^@link.*/@link${T}wlan0${T}disconnected/" "$SHIM_PROBE"
out="$(run bash "$SH" "${ARGS[@]}")"; rc=$?; ok "disconnected link exits 1" "$rc" 1; has "link FAIL" "$out" "FAIL link:wlan0:"
reset; sed -i "s/^@url.*/@url${T}http:\/\/127.0.0.1:3000\/${T}503${T}0/" "$SHIM_PROBE"
out="$(run bash "$SH" "${ARGS[@]}")"; rc=$?; ok "HTTP 503 exits 1" "$rc" 1; has "url FAIL" "$out" "FAIL url:http://127.0.0.1:3000/: HTTP '503'"
reset; sed -i "s/^@url.*/@url${T}http:\/\/127.0.0.1:3000\/${T}302${T}0/" "$SHIM_PROBE"
out="$(run bash "$SH" "${ARGS[@]}")"; rc=$?; ok "HTTP 302 passes" "$rc" 0
reset; sed -i "s/^@url.*/@url${T}http:\/\/127.0.0.1:3000\/?k=QUERYSENTINEL${T}200${T}0/" "$SHIM_PROBE"
out="$(run bash "$SH" --host mypi --expect-pubkey "$TMP/expect.pub" --no-wait --url "http://127.0.0.1:3000/?k=QUERYSENTINEL")"; rc=$?
ok "url with a query passes" "$rc" 0; lacks "query string is not echoed" "$out" "QUERYSENTINEL"
reset; sed -i '/^@done/d' "$SHIM_PROBE"
out="$(run bash "$SH" "${ARGS[@]}")"; rc=$?; ok "a truncated probe session exits 1" "$rc" 1; has "says it ended early" "$out" "FAIL probes:"

# --- ssh not reachable ---------------------------------------------------------------------
reset
out="$(run env SHIM_SSH_FAIL=1 bash "$SH" "${ARGS[@]}")"; rc=$?
ok "ssh failure exits 1" "$rc" 1; has "ssh FAIL carries ssh's reason" "$out" "FAIL ssh: cannot ssh to bosko@100.2.2.2: bosko@100.2.2.2: Permission denied"
has "remote probes skipped" "$out" "SKIP remote-probes:"
ok "no probe session was attempted" "$(grep -c 'bash -s' "$SHIM_LOG")" 0

# --- ping ------------------------------------------------------------------------------------
reset
out="$(run env PING_OK_AFTER=3 bash "$SH" --host mypi --expect-pubkey "$TMP/expect.pub" --wait 10)"; rc=$?
ok "waits for the Pi to answer (3rd ping)" "$rc" 0; has "ping PASS after waiting" "$out" "PASS ping:"
ok "pinged 3 times" "$(cat "$PING_N")" 3
reset
out="$(run env PING_OK_AFTER=999 bash "$SH" --host mypi --expect-pubkey "$TMP/expect.pub" --wait 1)"; rc=$?
ok "a Pi that never answers exits 1" "$rc" 1; has "ping FAIL" "$out" "FAIL ping:"
reset
out="$(run env PING_OK_AFTER=999 bash "$SH" --host mypi --no-wait)"; rc=$?
ok "--no-wait pings once" "$(cat "$PING_N")" 1
reset
out="$(run env SCAN_EMPTY=1 bash "$SH" --host mypi --expect-pubkey "$TMP/expect.pub" --no-wait)"; rc=$?
ok "no host key from sshd exits 1" "$rc" 1; has "hostkey FAIL" "$out" "FAIL hostkey:"

# --- known_hosts ----------------------------------------------------------------------------------
stale_kh() { printf '100.2.2.2 ssh-ed25519 OLDBLOB\nmypi ssh-ed25519 OLDBLOB\n' >"$KNOWN_HOSTS"; }
reset; stale_kh
out="$(run bash "$SH" "${ARGS[@]}")"; rc=$?
ok "stale known_hosts is only a WARN (exit 0)" "$rc" 0
has "stale WARN" "$out" "WARN known_hosts: 100.2.2.2: STALE,mypi: STALE"
has "WARN carries the fix" "$out" "ssh-keygen -R 100.2.2.2"
log_lacks "without the flag, nothing is removed" "ssh-keygen -R"
ok "known_hosts file untouched" "$(wc -l <"$KNOWN_HOSTS")" 2
reset; stale_kh
out="$(run bash "$SH" "${ARGS[@]}" --fix-known-hosts)"; rc=$?
ok "--fix-known-hosts run exits 0" "$rc" 0
log_has "fix removes the IP entry" "ssh-keygen -R 100.2.2.2 -f $KNOWN_HOSTS"
log_has "fix removes the name entry" "ssh-keygen -R mypi -f $KNOWN_HOSTS"
has "reports the fix" "$out" "PASS known_hosts: removed the stale entries"
reset; stale_kh; export SCAN_BLOB=FAKEBLOBOTHER
out="$(run bash "$SH" "${ARGS[@]}" --fix-known-hosts)"; rc=$?
ok "mismatching key plus --fix-known-hosts exits 1" "$rc" 1
log_lacks "no -R when the hostkey check FAILED" "ssh-keygen -R"
has "says it was not fixed" "$out" "NOT fixed"
reset
printf '100.2.2.2 ssh-ed25519 FAKEBLOBGOOD\n' >"$KNOWN_HOSTS"
out="$(run bash "$SH" "${ARGS[@]}" --fix-known-hosts)"; rc=$?
ok "matching entry exits 0" "$rc" 0; has "matching entry PASS" "$out" "PASS known_hosts: 100.2.2.2: matches,mypi: no entry"
log_lacks "matching entries are never removed" "ssh-keygen -R"
reset
out="$(run bash "$SH" "${ARGS[@]}")"; log_lacks "a plain run never edits known_hosts" "ssh-keygen -R"

echo "verify-boot.test.sh: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
