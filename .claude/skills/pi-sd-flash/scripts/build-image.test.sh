#!/usr/bin/env bash
# Tests for build-image.sh with a PATH shim for nix and a fixture hosts.json /
# throwaway git repo (never the real ones; no build is ever started).
# Run: bash .claude/skills/pi-sd-flash/scripts/build-image.test.sh
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SH="$HERE/build-image.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
SHIMS="$TMP/shims"
mkdir -p "$SHIMS"

cat >"$TMP/hosts.json" <<'JSON'
{
  "flakeHosts": ["gaming", "mypi"],
  "hosts": {
    "gaming": { "ssh": "bosko@gaming", "tailscaleIp": "100.1.1.1", "flakeHost": true, "arch": "x86_64-linux" },
    "mypi":   { "ssh": "bosko@mypi", "tailscaleIp": "100.2.2.2", "flakeHost": true, "arch": "aarch64-linux", "aliases": ["thepi"] }
  }
}
JSON

# throwaway repo with hosts/mypi committed and hosts/newpi untracked
REPO_FIX="$TMP/repo"
mkdir -p "$REPO_FIX/hosts/mypi" "$REPO_FIX/hosts/newpi"
echo '{ }' >"$REPO_FIX/hosts/mypi/configuration.nix"
git -C "$REPO_FIX" init -q
git -C "$REPO_FIX" add hosts/mypi
git -C "$REPO_FIX" -c user.name=t -c user.email=t@t commit -q -m fixture
echo '{ }' >"$REPO_FIX/hosts/newpi/configuration.nix"

FAKEOUT="$TMP/store/abc-sd-image"
mkdir -p "$FAKEOUT/sd-image"
printf 'placeholder' >"$FAKEOUT/sd-image/mypi.img.zst"
EMPTYOUT="$TMP/store/def-empty"
mkdir -p "$EMPTYOUT"

cat >"$SHIMS/nix" <<'SHIM'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$NIXLOG"
if [ -n "${NIX_FAIL:-}" ]; then echo "error: simulated failure" >&2; exit 1; fi
case " $* " in
  *" --dry-run "*)
    echo "this derivation will be built: /nix/store/fake.drv" >&2
    exit 0
    ;;
esac
printf '%s\n' "${NIX_OUT:-$FAKEOUT}"
SHIM
# pi_builder_ok reads uname -m: pretend to be aarch64 so the CLI path is machine-independent
cat >"$SHIMS/uname" <<'SHIM'
#!/usr/bin/env bash
echo aarch64
SHIM
chmod +x "$SHIMS"/*
export HOSTS_JSON="$TMP/hosts.json" PI_BACKUP_ROOT="$TMP/bk" PI_REPO="$REPO_FIX" NIXLOG="$TMP/nix.log" FAKEOUT

pass=0 fail=0
ok() { if [ "$2" = "$3" ]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL: $1 -- got '$2', wanted '$3'"; fi; }
has() { case "$2" in *"$3"*) pass=$((pass + 1)) ;; *) fail=$((fail + 1)); echo "FAIL: $1 -- output lacks '$3': $2" ;; esac; }
lacks() { case "$2" in *"$3"*) fail=$((fail + 1)); echo "FAIL: $1 -- output unexpectedly has '$3': $2" ;; *) pass=$((pass + 1)) ;; esac; }
run() { PATH="$SHIMS:$PATH" bash "$SH" "$@" 2>&1; }
# run_with_builder <0|1> <args>: source the script and force pi_builder_ok's answer
run_with_builder() {
  local b=$1
  shift
  PATH="$SHIMS:$PATH" BUILDER="$b" bash -c 'src=$1; shift; source "$src"; pi_builder_ok() { return "$BUILDER"; }; main "$@"' build-test "$SH" "$@" 2>&1
}

echo "--- build"
: >"$NIXLOG"
out=$(run mypi)
rc=$?
ok "build (rc)" "$rc" "0"
has "prints the image path" "$out" "IMAGE: $FAKEOUT/sd-image/mypi.img.zst"
ok "nix got the image attr" "$(cat "$NIXLOG")" "build $REPO_FIX#nixosConfigurations.mypi.config.system.build.sdImage --no-link --print-out-paths"
lacks "committed host: no untracked warning" "$out" "WARN"

: >"$NIXLOG"
out=$(run thepi)
has "alias resolves to the host" "$(cat "$NIXLOG")" "nixosConfigurations.mypi."

echo "--- --dry-run"
: >"$NIXLOG"
out=$(run mypi --dry-run)
rc=$?
ok "dry-run (rc)" "$rc" "0"
has "dry-run passes --dry-run to nix" "$(cat "$NIXLOG")" "--dry-run"
lacks "dry-run does not print out paths" "$(cat "$NIXLOG")" "--print-out-paths"
lacks "dry-run prints no IMAGE line" "$out" "IMAGE:"
has "dry-run shows what nix would build" "$out" "will be built"

echo "--- unregistered host with --ip"
: >"$NIXLOG"
out=$(run newpi --ip 100.9.9.9)
rc=$?
ok "unregistered host + --ip (rc)" "$rc" "0"
has "uses the unregistered host's attr" "$(cat "$NIXLOG")" "nixosConfigurations.newpi.config.system.build.sdImage"
has "warns about the untracked host dir" "$out" "WARN: untracked files"
has "names the untracked file" "$out" "hosts/newpi/"
has "tells you to git add" "$out" "git add"
out=$(run newpi)
ok "unregistered host without --ip refuses" "$?" "1"
has "says there is no IP" "$out" "no tailscaleIp"

echo "--- refusals"
out=$(run gaming)
ok "x86 host refuses (rc)" "$?" "1"
has "x86 host message" "$out" "not aarch64-linux"
out=$(run_with_builder 1 mypi)
ok "no aarch64 builder refuses (rc)" "$?" "1"
has "builder message names gaming" "$out" "Only gaming"
has "builder message mentions binfmt" "$out" "binfmt"
: >"$NIXLOG"
run_with_builder 1 mypi >/dev/null
ok "no builder: nix never called" "$(wc -c <"$NIXLOG" | tr -d ' ')" "0"
out=$(run_with_builder 0 mypi)
ok "builder ok succeeds (rc)" "$?" "0"
has "builder ok prints the image" "$out" "IMAGE:"

out=$(NIX_FAIL=1 run mypi)
ok "nix failure (rc)" "$?" "1"
has "nix failure message" "$out" "nix build failed"
out=$(NIX_OUT="$EMPTYOUT" run mypi)
ok "build without an image file (rc)" "$?" "1"
has "missing image message" "$out" "no .img.zst or .img under"

echo "--- usage"
run >/dev/null
ok "no host is a usage error" "$?" "2"
run mypi --bogus >/dev/null
ok "unknown option is a usage error" "$?" "2"
run mypi --ip >/dev/null
ok "--ip without a value is a usage error" "$?" "2"
run mypi extra >/dev/null
ok "two hosts is a usage error" "$?" "2"
out=$(run --help)
ok "--help exits 0" "$?" "0"
has "--help shows usage" "$out" "Usage: build-image.sh"

echo "build-image.test.sh: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
