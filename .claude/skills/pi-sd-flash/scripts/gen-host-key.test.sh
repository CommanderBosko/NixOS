#!/usr/bin/env bash
# Tests for gen-host-key.sh. NO REAL KEY IS EVER GENERATED: ssh-keygen and ssh-to-age
# are PATH shims that write/print dummy placeholder text, the suite asserts the shim is
# the one that resolves before every run, and the backup root is a temp dir.
# Run: bash .claude/skills/pi-sd-flash/scripts/gen-host-key.test.sh
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SH="$HERE/gen-host-key.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
SHIMS="$TMP/shims"
mkdir -p "$SHIMS" "$TMP/repo"
CALLS="$TMP/calls.log"

AGE="age1fixturefixturefixturefixturefixturefixturefixturefixture0000"
cat >"$TMP/hosts.json" <<'JSON'
{
  "flakeHosts": ["mypi"],
  "hosts": {
    "mypi": { "ssh": "bosko@mypi", "tailscaleIp": "100.2.2.2", "flakeHost": true, "arch": "aarch64-linux", "aliases": ["thepi"] }
  }
}
JSON
cat >"$TMP/repo/.sops.yaml" <<YAML
keys:
  - &admin age1adminadminadminadminadminadminadminadminadminadminadmin0000
  - &mypi $AGE
YAML

cat >"$SHIMS/ssh-keygen" <<'SHIM'
#!/usr/bin/env bash
# SHIM: records the call and writes dummy placeholder text. Generates nothing real.
printf '%s\n' "$*" >>"$CALLS"
f=""
while [ $# -gt 0 ]; do
  [ "$1" = -f ] && f=$2
  shift
done
[ -n "$f" ] || exit 2
printf 'PLACEHOLDER-PRIVATE-MARKER-NOT-A-KEY\n' >"$f"
chmod 666 "$f" # prove the script, not the shim, tightens the mode
printf 'ssh-ed25519 AAAAdummyplaceholder mypi-host-key\n' >"$f.pub"
chmod 600 "$f.pub"
SHIM
cat >"$SHIMS/ssh-to-age" <<'SHIM'
#!/usr/bin/env bash
cat >/dev/null
echo "${SHIM_AGE:-$FIXTURE_AGE}"
SHIM
cat >"$SHIMS/nix" <<'SHIM'
#!/usr/bin/env bash
printf 'nix %s\n' "$*" >>"$CALLS"
cat >/dev/null
echo "$FIXTURE_AGE"
SHIM
chmod +x "$SHIMS"/*
export HOSTS_JSON="$TMP/hosts.json" PI_BACKUP_ROOT="$TMP/bk" PI_REPO="$TMP/repo" CALLS FIXTURE_AGE="$AGE"
export PATH="$SHIMS:$PATH"

# hard stop if the real ssh-keygen could be reached instead of the shim
[ "$(command -v ssh-keygen)" = "$SHIMS/ssh-keygen" ] || { echo "ABORT: ssh-keygen does not resolve to the shim"; exit 1; }
[ "$(command -v ssh-to-age)" = "$SHIMS/ssh-to-age" ] || { echo "ABORT: ssh-to-age does not resolve to the shim"; exit 1; }

pass=0 fail=0
ok() { if [ "$2" = "$3" ]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL: $1 -- got '$2', wanted '$3'"; fi; }
has() { case "$2" in *"$3"*) pass=$((pass + 1)) ;; *) fail=$((fail + 1)); echo "FAIL: $1 -- output lacks '$3': $2" ;; esac; }
lacks() { case "$2" in *"$3"*) fail=$((fail + 1)); echo "FAIL: $1 -- output unexpectedly has '$3': $2" ;; *) pass=$((pass + 1)) ;; esac; }
run() { bash "$SH" "$@" 2>&1; }
called() { if [ -s "$CALLS" ]; then echo called; else echo none; fi; }
KEYDIR="$TMP/bk/mypi/ssh-host"

echo "--- --check on a fresh host"
: >"$CALLS"
out=$(run mypi --check)
ok "check on empty (rc)" "$?" "0"
has "check says it would generate" "$out" "would GENERATE"
ok "check created nothing" "$([ -e "$TMP/bk" ] && echo exists || echo none)" "none"
ok "check ran no tool" "$(called)" "none"

echo "--- generate (shimmed ssh-keygen: dummy files only)"
: >"$CALLS"
out=$(run mypi)
rc=$?
ok "generate (rc)" "$rc" "0"
ok "ssh-keygen got the documented arguments" "$(cat "$CALLS")" "-q -t ed25519 -N  -C mypi-host-key -f $KEYDIR/ssh_host_ed25519_key"
ok "key dir mode" "$(stat -c %a "$KEYDIR")" "700"
ok "backup dir mode" "$(stat -c %a "$TMP/bk/mypi")" "700"
ok "private key mode" "$(stat -c %a "$KEYDIR/ssh_host_ed25519_key")" "600"
ok "public key mode" "$(stat -c %a "$KEYDIR/ssh_host_ed25519_key.pub")" "644"
has "prints the public key line" "$out" "ssh-ed25519 AAAAdummyplaceholder mypi-host-key"
has "prints the age recipient" "$out" "$AGE"
has "prints the sops anchor for the host" "$out" "- &mypi $AGE"
has "prints the common.yaml rule" "$out" 'secrets/common\.yaml$'
has "prints the per-host rule" "$out" 'secrets/hosts/mypi\.yaml$'
has "points at sops-registration.md" "$out" "new-host/references/sops-registration.md"
has "points at sops-bootstrap.md" "$out" "pi-sd-flash/references/sops-bootstrap.md"
has "reminds the private key goes only onto the media" "$out" "ONLY onto the media"
lacks "never prints the private key" "$out" "PLACEHOLDER-PRIVATE-MARKER"

echo "--- refuses to overwrite"
before=$(cksum "$KEYDIR/ssh_host_ed25519_key" "$KEYDIR/ssh_host_ed25519_key.pub")
: >"$CALLS"
out=$(run mypi)
ok "second generate refuses (rc)" "$?" "1"
has "refusal message" "$out" "REFUSING: a host key already exists"
ok "refusal did not call ssh-keygen" "$(called)" "none"
ok "refusal left the files untouched" "$(cksum "$KEYDIR/ssh_host_ed25519_key" "$KEYDIR/ssh_host_ed25519_key.pub")" "$before"
out=$(run mypi --check)
ok "check on existing key (rc)" "$?" "1"
has "check says it would refuse" "$out" "would REFUSE"
rm "$KEYDIR/ssh_host_ed25519_key"
: >"$CALLS"
out=$(run mypi)
ok "a lone .pub still refuses (rc)" "$?" "1"
ok "a lone .pub did not call ssh-keygen" "$(called)" "none"
printf 'PLACEHOLDER-PRIVATE-MARKER-NOT-A-KEY\n' >"$KEYDIR/ssh_host_ed25519_key"
chmod 600 "$KEYDIR/ssh_host_ed25519_key"

echo "--- --show reads only the .pub"
chmod 000 "$KEYDIR/ssh_host_ed25519_key" # unreadable: any read of it would fail loudly
out=$(run thepi --show)
ok "show (rc)" "$?" "0"
has "show prints the public key" "$out" "ssh-ed25519 AAAAdummyplaceholder mypi-host-key"
has "show prints the age recipient" "$out" "$AGE"
has "show reports it is registered" "$out" "registered in .sops.yaml: YES"
lacks "show never prints the private key" "$out" "PLACEHOLDER-PRIVATE-MARKER"
chmod 600 "$KEYDIR/ssh_host_ed25519_key"
out=$(SHIM_AGE="age1notinsops000000000000000000000000000000000000000000000000" run mypi --show)
has "show reports an unregistered recipient" "$out" "registered in .sops.yaml: NO"
rm -rf "$TMP/bk"
out=$(run mypi --show)
ok "show without a key (rc)" "$?" "1"
has "show without a key message" "$out" "no public key"

echo "--- age fallback and keygen preflight (sourced functions)"
mkdir -p "$TMP/nixonly"
ln -s "$SHIMS/nix" "$TMP/nixonly/nix"
ln -s "$(command -v bash)" "$TMP/nixonly/bash" # the shim's shebang and its cat need these on the restricted PATH
ln -s "$(command -v cat)" "$TMP/nixonly/cat"
: >"$CALLS"
out=$(bash -c 'src=$1; shift; source "$src"; PATH=$1; echo dummy-pub >"$2"; age_of_pub "$2"' t "$SH" "$TMP/nixonly" "$TMP/dummy.pub" 2>&1)
ok "age via nix shell when ssh-to-age is absent" "$out" "$AGE"
has "it used nix shell nixpkgs#ssh-to-age" "$(cat "$CALLS")" "nix shell nixpkgs#ssh-to-age -c ssh-to-age"
out=$(bash -c 'src=$1; shift; source "$src"; PI_NAME=mypi; PATH=/nonexistent; need_keygen' t "$SH" 2>&1)
ok "need_keygen refuses without ssh-keygen (rc)" "$(bash -c 'src=$1; shift; source "$src"; PI_NAME=mypi; PATH=/nonexistent; need_keygen' t "$SH" >/dev/null 2>&1; echo $?)" "1"
has "need_keygen hints nix shell" "$out" "nix shell nixpkgs#openssh"

echo "--- usage"
run >/dev/null
ok "no host is a usage error" "$?" "2"
run mypi --check --show >/dev/null
ok "--check with --show is a usage error" "$?" "2"
run mypi --bogus >/dev/null
ok "unknown option is a usage error" "$?" "2"
run mypi --ip >/dev/null
ok "--ip without a value is a usage error" "$?" "2"
run '../evil' >/dev/null
ok "path-ish host name is a usage error" "$?" "2"
run mypi extra >/dev/null
ok "two hosts is a usage error" "$?" "2"
out=$(run --help)
ok "--help exits 0" "$?" "0"
has "--help shows usage" "$out" "Usage: gen-host-key.sh"
out=$(run nosuchpi)
ok "unknown host without --ip refuses (rc)" "$?" "1"
has "unknown host message" "$out" "no tailscaleIp"
ok "usage errors created nothing" "$([ -e "$TMP/bk" ] && echo exists || echo none)" "none"

echo "gen-host-key.test.sh: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
