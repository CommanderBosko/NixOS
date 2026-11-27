#!/usr/bin/env bash
# Tests for compare-snapshot.sh. curl and ssh are PATH shims that serve a
# fixture JSON file; nothing touches the network.
# Run: bash .claude/skills/pi-cutover/scripts/compare-snapshot.test.sh
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SH="$HERE/compare-snapshot.sh"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
SHIMS="$TMP/shims"; mkdir -p "$SHIMS"
export SHIM_LOG="$TMP/calls.log" SHIM_BODY="$TMP/served.json"

pass=0 fail=0
ok() { if [ "$2" = "$3" ]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL: $1 -- got '$2', wanted '$3'"; fi; }
has() { case "$2" in *"$3"*) pass=$((pass + 1)) ;; *) fail=$((fail + 1)); echo "FAIL: $1 -- output lacks '$3'"; echo "$2" | head -n 20 ;; esac; }
lacks() { case "$2" in *"$3"*) fail=$((fail + 1)); echo "FAIL: $1 -- output contains '$3'" ;; *) pass=$((pass + 1)) ;; esac; }
log_has() { if grep -qF -- "$2" "$SHIM_LOG" 2>/dev/null; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL: $1 -- call log lacks '$2'"; fi; }

cat >"$SHIMS/curl" <<'EOS'
#!/usr/bin/env bash
echo "curl $*" >>"$SHIM_LOG"
[ "${SHIM_CURL_FAIL:-0}" = 1 ] && { echo "curl: (22) The requested URL returned error: 404" >&2; exit 22; }
last="${*: -1}"; name="${last##*/}"
if [ -n "${SHIM_SERVE:-}" ] && [ -f "$SHIM_SERVE/$name" ]; then cat "$SHIM_SERVE/$name"; exit 0; fi
cat "$SHIM_BODY"
EOS
cat >"$SHIMS/ssh" <<'EOS'
#!/usr/bin/env bash
echo "ssh $*" >>"$SHIM_LOG"
while [ $# -gt 0 ]; do case "$1" in -o) shift 2 ;; -*) shift ;; *) break ;; esac; done
shift  # target; the rest is the remote command line
[ "${SHIM_SSH_FAIL:-0}" = 1 ] && { echo "ssh: connect to host failed" >&2; exit 255; }
last="${*: -1}"; name="${last##*/}"
if [ -n "${SHIM_SERVE:-}" ] && [ -f "$SHIM_SERVE/$name" ]; then cat "$SHIM_SERVE/$name"; exit 0; fi
cat "$SHIM_BODY"
EOS
chmod +x "$SHIMS"/*
run() { PATH="$SHIMS:$PATH" "$@" 2>&1; }

SENT="TOP-SECRET-SENTINEL-4711"
cat >"$TMP/snap.json" <<JSON
{ "members": [ {"name": "$SENT"}, {"name": "b"}, {"name": "c"} ],
  "settings": { "theme": "dark", "tz": "$SENT" },
  "version": 3,
  "stamp": "2026-11-26T10:00:00Z" }
JSON
# same data, keys in another order and different whitespace
cat >"$TMP/live-same.json" <<JSON
{"stamp":"2026-11-26T10:00:00Z","version":3,"settings":{"tz":"$SENT","theme":"dark"},"members":[{"name":"$SENT"},{"name":"b"},{"name":"c"}]}
JSON

# --- usage ------------------------------------------------------------------------
out="$(run bash "$SH" --help)"; rc=$?; ok "help exits 0" "$rc" 0; has "help text" "$out" "--ignore-key"
out="$(run bash "$SH")"; rc=$?; ok "no args is a usage error" "$rc" 2
out="$(run bash "$SH" --snapshot "$TMP/snap.json")"; rc=$?; ok "no live side is a usage error" "$rc" 2
out="$(run bash "$SH" --snapshot "$TMP/snap.json" --url http://x/ --live-file "$TMP/live-same.json")"; rc=$?; ok "url and live-file together is a usage error" "$rc" 2
out="$(run bash "$SH" --snapshot "$TMP/snap.json" --live-file "$TMP/live-same.json" --via bosko@x)"; rc=$?; ok "--via without --url is a usage error" "$rc" 2
out="$(run bash "$SH" --snapshot "$TMP/snap.json" --url ftp://x)"; rc=$?; ok "non-http url is a usage error" "$rc" 2
out="$(run bash "$SH" --snapshot "$TMP/nope.json" --live-file "$TMP/live-same.json")"; rc=$?; ok "missing snapshot is a usage error" "$rc" 2
printf '{ not json' >"$TMP/bad.json"
out="$(run bash "$SH" --snapshot "$TMP/bad.json" --live-file "$TMP/live-same.json")"; rc=$?; ok "invalid snapshot JSON is an input error" "$rc" 2
out="$(run bash "$SH" --snapshot "$TMP/snap.json" --live-file "$TMP/bad.json")"; rc=$?; ok "invalid live JSON is an input error" "$rc" 2

# --- identical content, different key order -> MATCH ---------------------------------------
out="$(run bash "$SH" --snapshot "$TMP/snap.json" --live-file "$TMP/live-same.json")"; rc=$?
ok "reordered but equal JSON exits 0" "$rc" 0
has "verdict MATCH" "$out" "VERDICT: MATCH (4 key(s) compared"
has "array count" "$out" "members"; has "members row" "$(echo "$out" | grep '^members')" "3          3  MATCH"
has "object count" "$(echo "$out" | grep '^settings')" "2          2  MATCH"
has "scalar count" "$(echo "$out" | grep '^version')" "1          1  MATCH"
lacks "never prints values (sentinel)" "$out" "$SENT"
lacks "never prints values (theme)" "$out" "dark"

# --- changed value with the same counts -> DIFF -----------------------------------------------
sed "s/\"theme\": \"dark\"/\"theme\": \"light\"/; s/\"theme\":\"dark\"/\"theme\":\"light\"/" "$TMP/live-same.json" >"$TMP/live-diff.json"
out="$(run bash "$SH" --snapshot "$TMP/snap.json" --live-file "$TMP/live-diff.json")"; rc=$?
ok "a changed value exits 1" "$rc" 1
has "verdict DIFF" "$out" "VERDICT: DIFF (1 of 4 key(s) differ"
has "the changed key is DIFF" "$(echo "$out" | grep '^settings')" "DIFF"
has "equal counts still shown" "$(echo "$out" | grep '^settings')" "2          2  DIFF"
has "DIFF rows carry short hashes" "$(echo "$out" | grep '^settings')" "snapshot #"
has "other keys still MATCH" "$(echo "$out" | grep '^members')" "MATCH"
lacks "never prints values on a diff" "$out" "light"
lacks "never prints the sentinel on a diff" "$out" "$SENT"

# --- count differences and missing keys ---------------------------------------------------------
cat >"$TMP/live-short.json" <<JSON
{"members":[{"name":"a"}],"settings":{"theme":"dark","tz":"x"},"version":3,"stamp":"2026-11-26T10:00:00Z","extra":[1,2]}
JSON
out="$(run bash "$SH" --snapshot "$TMP/snap.json" --live-file "$TMP/live-short.json")"; rc=$?
ok "fewer members exits 1" "$rc" 1
has "members shows 3 vs 1" "$(echo "$out" | grep '^members')" "3          1  DIFF"
has "key only in live shows a dash for the snapshot" "$(echo "$out" | grep '^extra')" "-          2  DIFF"

# --- --ignore-key --------------------------------------------------------------------------------------
sed 's/"stamp":"2026-11-26T10:00:00Z"/"stamp":"2099-01-01T00:00:00Z"/' "$TMP/live-same.json" >"$TMP/live-stamp.json"
out="$(run bash "$SH" --snapshot "$TMP/snap.json" --live-file "$TMP/live-stamp.json")"; rc=$?
ok "a moved timestamp is a DIFF by default" "$rc" 1
out="$(run bash "$SH" --snapshot "$TMP/snap.json" --live-file "$TMP/live-stamp.json" --ignore-key stamp)"; rc=$?
ok "--ignore-key makes it pass" "$rc" 0
has "ignored row is labelled" "$(echo "$out" | grep '^stamp')" "IGNORED"
has "verdict counts the ignored key" "$out" "3 key(s) compared, 1 ignored"
out="$(run bash "$SH" --snapshot "$TMP/snap.json" --live-file "$TMP/live-stamp.json" --ignore-key stamp --ignore-key version --ignore-key members --ignore-key settings)"; rc=$?
ok "ignoring every key is a usage-level error" "$rc" 2

# --- non-object documents ---------------------------------------------------------------------------------
echo '[1,2,3]' >"$TMP/a1.json"; echo '[3,2,1]' >"$TMP/a2.json"
out="$(run bash "$SH" --snapshot "$TMP/a1.json" --live-file "$TMP/a1.json")"; rc=$?
ok "equal arrays match" "$rc" 0; has "(root) row" "$out" "(root)"
out="$(run bash "$SH" --snapshot "$TMP/a1.json" --live-file "$TMP/a2.json")"; rc=$?
ok "array order matters" "$rc" 1

# --- fetching -------------------------------------------------------------------------------------------------
cp "$TMP/live-same.json" "$SHIM_BODY"; : >"$SHIM_LOG"
out="$(run bash "$SH" --snapshot "$TMP/snap.json" --url "http://127.0.0.1:3000/api/data?x=1&y=2")"; rc=$?
ok "--url fetch matches" "$rc" 0
log_has "curl got the url" "http://127.0.0.1:3000/api/data?x=1&y=2"
log_has "curl fails on HTTP errors and has a timeout" "-sS -f -m 20"
: >"$SHIM_LOG"
out="$(run bash "$SH" --snapshot "$TMP/snap.json" --url "http://127.0.0.1:3000/api/data?x=1&y=2" --via bosko@100.2.2.2)"; rc=$?
ok "--via fetch matches" "$rc" 0
log_has "ssh ran BatchMode" "BatchMode=yes"
log_has "ssh went to the target" "bosko@100.2.2.2"
log_has "the url is shell-quoted for the remote side" 'http://127.0.0.1:3000/api/data\?x=1\&y=2'
out="$(run env SHIM_CURL_FAIL=1 bash "$SH" --snapshot "$TMP/snap.json" --url http://127.0.0.1:3000/)"; rc=$?
ok "a failed fetch is an input error" "$rc" 2; has "fetch error is reported" "$out" "could not fetch"
out="$(run env SHIM_SSH_FAIL=1 bash "$SH" --snapshot "$TMP/snap.json" --url http://127.0.0.1:3000/ --via bosko@100.2.2.2)"; rc=$?
ok "a failed ssh fetch is an input error" "$rc" 2

# --- --key-url: per-collection endpoints ------------------------------------------------------------------
SERVE="$TMP/serve"; mkdir -p "$SERVE"; export SHIM_SERVE="$SERVE"
printf '[{"name":"%s"},{"name":"b"},{"name":"c"}]' "$SENT" >"$SERVE/members"
printf '{"theme":"dark","tz":"%s"}' "$SENT" >"$SERVE/settings"
: >"$SHIM_LOG"
out="$(run bash "$SH" --snapshot "$TMP/snap.json" --key-url members=http://127.0.0.1:3000/members --key-url settings=http://127.0.0.1:3000/settings)"; rc=$?
ok "--key-url all match exits 0" "$rc" 0
has "verdict counts only the listed keys" "$out" "VERDICT: MATCH (2 key(s) compared"
lacks "unlisted snapshot keys are not compared" "$out" "stamp"
lacks "key-url never prints values" "$out" "$SENT"
log_has "curl hit the members endpoint" "http://127.0.0.1:3000/members"
log_has "curl hit the settings endpoint" "http://127.0.0.1:3000/settings"
: >"$SHIM_LOG"
out="$(run bash "$SH" --snapshot "$TMP/snap.json" --key-url members=http://127.0.0.1:3000/members --via bosko@100.2.2.2)"; rc=$?
ok "--key-url with --via matches" "$rc" 0
log_has "key-url via ssh ran BatchMode" "BatchMode=yes"
log_has "key-url via ssh went to the target" "bosko@100.2.2.2"
printf '[{"name":"a"}]' >"$SERVE/members"
out="$(run bash "$SH" --snapshot "$TMP/snap.json" --key-url members=http://127.0.0.1:3000/members --key-url settings=http://127.0.0.1:3000/settings)"; rc=$?
ok "--key-url with a changed collection exits 1" "$rc" 1
has "changed collection shows 3 vs 1" "$(echo "$out" | grep '^members')" "3          1  DIFF"
has "unchanged collection still MATCH" "$(echo "$out" | grep '^settings')" "MATCH"
lacks "key-url diff never prints values" "$out" "$SENT"
out="$(run bash "$SH" --snapshot "$TMP/snap.json" --key-url nosuch=http://127.0.0.1:3000/members)"; rc=$?
ok "a key missing from the snapshot is a DIFF" "$rc" 1
has "missing key shows a dash on the snapshot side" "$(echo "$out" | grep '^nosuch')" "-          1  DIFF"
out="$(run bash "$SH" --snapshot "$TMP/snap.json" --key-url members)"; rc=$?; ok "--key-url without =URL is a usage error" "$rc" 2
out="$(run bash "$SH" --snapshot "$TMP/snap.json" --key-url =http://x/)"; rc=$?; ok "--key-url with an empty key is a usage error" "$rc" 2
out="$(run bash "$SH" --snapshot "$TMP/snap.json" --key-url members=ftp://x/)"; rc=$?; ok "--key-url with a non-http URL is a usage error" "$rc" 2
out="$(run bash "$SH" --snapshot "$TMP/snap.json" --key-url members=http://x/ --url http://y/)"; rc=$?; ok "--key-url and --url together is a usage error" "$rc" 2
out="$(run bash "$SH" --snapshot "$TMP/a1.json" --key-url members=http://127.0.0.1:3000/members)"; rc=$?; ok "--key-url needs an object snapshot" "$rc" 2
printf '{ not json' >"$SERVE/members"
out="$(run bash "$SH" --snapshot "$TMP/snap.json" --key-url members=http://127.0.0.1:3000/members)"; rc=$?; ok "invalid JSON from a key endpoint is an input error" "$rc" 2
unset SHIM_SERVE

echo "compare-snapshot.test.sh: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
