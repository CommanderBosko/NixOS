#!/usr/bin/env bash
# Tests for stage-remote.sh. ssh and scp are PATH shims over a LOCAL directory that plays
# the "remote" machine, so no real host is ever contacted; keys are dummy placeholder text.
# Run: bash .claude/skills/pi-sd-flash/scripts/stage-remote.test.sh
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SH="$HERE/stage-remote.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
SHIMS="$TMP/shims"
FAKEREMOTE="$TMP/remote"
SSHLOG="$TMP/ssh.log"
SCPLOG="$TMP/scp.log"
mkdir -p "$SHIMS" "$FAKEREMOTE"

cat >"$TMP/hosts.json" <<'JSON'
{
  "flakeHosts": ["mypi", "natalie-laptop"],
  "hosts": {
    "mypi":           { "ssh": "bosko@mypi", "tailscaleIp": "100.2.2.2", "flakeHost": true, "arch": "aarch64-linux" },
    "natalie-laptop": { "ssh": "bosko@natalie-laptop", "tailscaleIp": "100.3.3.3", "flakeHost": true, "arch": "x86_64-linux", "aliases": ["natalie"] }
  }
}
JSON

# ssh shim: the command is the LAST argument; "remote" paths are really local ones under $FAKEREMOTE
cat >"$SHIMS/ssh" <<'SHIM'
#!/usr/bin/env bash
cmd="${!#}"
printf '%s\n' "$*" >>"$SSHLOG"
case "$cmd" in
  *"mktemp -d"*)
    d="$FAKEREMOTE/pi-flash.abc123"
    mkdir -p "$d"
    echo "$d"
    ;;
  mkdir*) bash -c "$cmd" ;;
  stat*)
    if [ -n "${FAKE_STAT:-}" ]; then echo "$FAKE_STAT"; else bash -c "$cmd"; fi
    ;;
  *"flash-pi-media.sh --check"*)
    echo "OK: fake device check"
    exit "${FAKE_CHECK_RC:-0}"
    ;;
  *"flash-pi-media.sh --plan"*)
    echo "PLAN: fake plan"
    exit "${FAKE_PLAN_RC:-0}"
    ;;
  *) echo "ssh shim: unexpected command: $cmd" >&2; exit 99 ;;
esac
SHIM
# scp shim: copy into the fake remote dir; supports several sources before one target:dest
cat >"$SHIMS/scp" <<'SHIM'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$SCPLOG"
[ -z "${SCP_FAIL:-}" ] || { echo "scp: simulated failure" >&2; exit 1; }
srcs=()
while [ $# -gt 0 ]; do
  case "$1" in
    -q) ;;
    -o) shift ;;
    *) srcs+=("$1") ;;
  esac
  shift
done
dest="${srcs[${#srcs[@]} - 1]}"
dest="${dest#*:}"
unset 'srcs[${#srcs[@]}-1]'
cp "${srcs[@]}" "$dest"
SHIM
chmod +x "$SHIMS"/*
export HOSTS_JSON="$TMP/hosts.json" PI_BACKUP_ROOT="$TMP/bk" SSHLOG SCPLOG FAKEREMOTE

IMG="$TMP/pi.img.zst"
printf 'placeholder-image-bytes' >"$IMG"
RAW="$TMP/pi.img"
printf 'placeholder-raw' >"$RAW"
KEYS="$TMP/keys"
mkdir -p "$KEYS"
printf 'PLACEHOLDER-PRIVATE-MARKER-NOT-A-KEY\n' >"$KEYS/ssh_host_ed25519_key"
printf 'ssh-ed25519 AAAAdummy placeholder\n' >"$KEYS/ssh_host_ed25519_key.pub"
STATE="$TMP/tailscaled.state"
printf '{"placeholder":true}\n' >"$STATE"
DIR="$FAKEREMOTE/pi-flash.abc123"

pass=0 fail=0
ok() { if [ "$2" = "$3" ]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL: $1 -- got '$2', wanted '$3'"; fi; }
has() { case "$2" in *"$3"*) pass=$((pass + 1)) ;; *) fail=$((fail + 1)); echo "FAIL: $1 -- output lacks '$3': $2" ;; esac; }
lacks() { case "$2" in *"$3"*) fail=$((fail + 1)); echo "FAIL: $1 -- output unexpectedly has '$3': $2" ;; *) pass=$((pass + 1)) ;; esac; }
run() { PATH="$SHIMS:$PATH" bash "$SH" "$@" 2>&1; }
reset() { rm -rf "$FAKEREMOTE"; mkdir -p "$FAKEREMOTE"; : >"$SSHLOG"; : >"$SCPLOG"; }
nlines() { wc -l <"$1" | tr -d ' '; }
count_entries() { local -a e=("$1"/*); if [ -e "${e[0]}" ]; then echo "${#e[@]}"; else echo 0; fi; }

echo "--- full run with --device"
reset
out=$(run mypi natalie "$IMG" "$KEYS" "$STATE" --device /dev/sda)
rc=$?
ok "full run (rc)" "$rc" "0"
for f in image.img.zst flash-pi-media.sh keys/ssh_host_ed25519_key keys/ssh_host_ed25519_key.pub tailscaled.state; do
  ok "staged $f" "$([ -f "$DIR/$f" ] && echo yes || echo no)" "yes"
done
ok "staged script is the real flash-pi-media.sh" "$([ "$(cksum <"$DIR/flash-pi-media.sh")" = "$(cksum <"$HERE/flash-pi-media.sh")" ] && echo same || echo different)" "same"
ok "ssh got mktemp with umask 077" "$(grep -c "umask 077; mktemp -d /tmp/pi-flash.XXXXXX" "$SSHLOG")" "1"
has "alias natalie resolved through hosts.json" "$(cat "$SSHLOG")" "bosko@natalie-laptop"
has "remote --check ran on the device" "$(cat "$SSHLOG")" "flash-pi-media.sh --check /dev/sda"
has "remote --plan ran with the staged paths" "$(cat "$SSHLOG")" "flash-pi-media.sh --plan /dev/sda $DIR/image.img.zst $DIR/keys $DIR/tailscaled.state"
has "reports the intact copy" "$out" "PASS: image copied intact"
has "hand-off 1 is the single sudo command" "$out" "  ssh -t bosko@natalie-laptop sudo bash $DIR/flash-pi-media.sh /dev/sda $DIR/image.img.zst $DIR/keys $DIR/tailscaled.state"
has "hand-off 2 is the cleanup" "$out" "  ssh -t bosko@natalie-laptop rm -rf $DIR"
has "mentions the dd silence" "$out" "1.4 GB/s"
has "mentions the two-nodes rule" "$out" "Do NOT power the old card/disk"
has "says the cleanup is mandatory-ish" "$out" "PRIVATE host key"
lacks "never prints key material" "$out" "PLACEHOLDER-PRIVATE-MARKER"
ok "exactly two hand-off commands are printed" "$(printf '%s\n' "$out" | grep -c '^  ssh -t ')" "2"
ok "the script itself ran no sudo and no rm" "$(grep -cE 'sudo|rm -rf' "$SSHLOG")" "0"

echo "--- without --device / without state"
reset
out=$(run mypi bosko@box.example "$RAW" "$KEYS")
ok "no device, no state (rc)" "$?" "0"
has "raw image keeps its extension" "$out" "/image.img /"
has "device is an explicit placeholder" "$out" "sudo bash $DIR/flash-pi-media.sh <DEVICE> $DIR/image.img $DIR/keys"
lacks "no state: no tailscaled.state in the command" "$out" "tailscaled.state"
ok "no device: no remote check ran" "$(grep -c 'flash-pi-media.sh --' "$SSHLOG")" "0"
has "raw target used verbatim" "$(cat "$SSHLOG")" "bosko@box.example"
has "suggests re-running with --device" "$out" "--device"

echo "--- --dry-run"
reset
out=$(run mypi natalie "$IMG" "$KEYS" "$STATE" --device /dev/sda --dry-run)
ok "dry-run (rc)" "$?" "0"
ok "dry-run ran no ssh" "$(nlines "$SSHLOG")" "0"
ok "dry-run ran no scp" "$(nlines "$SCPLOG")" "0"
ok "dry-run staged nothing" "$(count_entries "$FAKEREMOTE")" "0"
has "dry-run lists the mktemp" "$out" "mktemp -d /tmp/pi-flash.XXXXXX"
has "dry-run lists the image scp" "$out" "scp $IMG bosko@natalie-laptop:<REMOTE_DIR>/image.img.zst"
has "dry-run lists the key scp" "$out" "bosko@natalie-laptop:<REMOTE_DIR>/keys/"
has "dry-run lists the remote check" "$out" "flash-pi-media.sh --check /dev/sda"
has "dry-run admits the device is unchecked" "$out" "has NOT been checked"
has "dry-run hand-off uses the placeholder dir" "$out" "rm -rf <REMOTE_DIR>"

echo "--- remote refusals"
reset
out=$(FAKE_CHECK_RC=1 run mypi natalie "$IMG" "$KEYS" "$STATE" --device /dev/sda)
ok "remote --check refusal (rc)" "$?" "1"
has "refusal is reported" "$out" "refused /dev/sda"
lacks "no flash hand-off after a refusal" "$out" "sudo bash"
has "cleanup hand-off still printed" "$out" "ssh -t bosko@natalie-laptop rm -rf $DIR"
reset
out=$(FAKE_PLAN_RC=1 run mypi natalie "$IMG" "$KEYS" --device /dev/sda)
ok "remote --plan refusal (rc)" "$?" "1"
lacks "no flash hand-off after a plan refusal" "$out" "sudo bash"
reset
out=$(SCP_FAIL=1 run mypi natalie "$IMG" "$KEYS")
ok "scp failure (rc)" "$?" "1"
has "scp failure reported" "$out" "staging to bosko@natalie-laptop failed"
has "scp failure still hands off the cleanup" "$out" "rm -rf $DIR"
lacks "scp failure prints no flash command" "$out" "sudo bash"
reset
out=$(FAKE_STAT=999 run mypi natalie "$IMG" "$KEYS")
ok "size mismatch (rc)" "$?" "1"
has "size mismatch reported" "$out" "truncated copy"

echo "--- local input problems never reach the network"
reset
run mypi natalie "$TMP/missing.img.zst" "$KEYS" >/dev/null
ok "missing image (rc)" "$?" "1"
run mypi natalie "$KEYS/ssh_host_ed25519_key.pub" "$KEYS" >/dev/null
ok "unknown image extension (rc)" "$?" "1"
run mypi natalie "$IMG" "$TMP/no-keys" >/dev/null
ok "missing key dir (rc)" "$?" "1"
run mypi natalie "$IMG" "$KEYS" "$TMP/no-state" >/dev/null
ok "missing state (rc)" "$?" "1"
ok "none of them ran ssh or scp" "$(($(nlines "$SSHLOG") + $(nlines "$SCPLOG")))" "0"

echo "--- usage"
run >/dev/null
ok "no arguments is a usage error" "$?" "2"
run mypi natalie "$IMG" >/dev/null
ok "too few arguments is a usage error" "$?" "2"
run mypi natalie "$IMG" "$KEYS" "$STATE" extra >/dev/null
ok "too many arguments is a usage error" "$?" "2"
run mypi natalie "$IMG" "$KEYS" --bogus >/dev/null
ok "unknown option is a usage error" "$?" "2"
run mypi natalie "$IMG" "$KEYS" --device >/dev/null
ok "--device without a value is a usage error" "$?" "2"
run mypi natalie "$IMG" "$KEYS" --device '/dev/sda; rm -rf /' >/dev/null
ok "shell metacharacters in --device are a usage error" "$?" "2"
run mypi natalie "$IMG" "$KEYS" --device sda >/dev/null
ok "non-/dev --device is a usage error" "$?" "2"
run mypi '-oProxyCommand=evil' "$IMG" "$KEYS" >/dev/null
ok "option-looking flasher is a usage error" "$?" "2"
run mypi 'a b' "$IMG" "$KEYS" >/dev/null
ok "flasher with a space is a usage error" "$?" "2"
ok "usage errors ran no ssh or scp" "$(($(nlines "$SSHLOG") + $(nlines "$SCPLOG")))" "0"
out=$(run --help)
ok "--help exits 0" "$?" "0"
has "--help shows usage" "$out" "Usage: stage-remote.sh"

echo "stage-remote.test.sh: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
