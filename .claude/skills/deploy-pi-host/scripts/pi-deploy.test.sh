#!/usr/bin/env bash
# Tests for pi-deploy.sh. Everything runs against PATH shims (nix, ssh, git, ...)
# and a fixture hosts.json: no real host, network, nix store or sudo is touched.
# The shims for ssh-keygen/ssh-keyscan/scp/ping/curl/rsync/sudo are poison: any
# call fails the run.
# Run: bash .claude/skills/deploy-pi-host/scripts/pi-deploy.test.sh
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SH="$HERE/pi-deploy.sh"
command -v jq >/dev/null 2>&1 || { echo "pi-deploy.test.sh: jq not installed, skipped"; exit 0; }
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
SHIMS="$TMP/shims"; FX="$TMP/fx"; CALLS="$TMP/calls.log"; ALL="$TMP/all-calls.log"
mkdir -p "$SHIMS" "$FX"; : >"$CALLS"; : >"$ALL"

cat >"$TMP/hosts.json" <<'JSON'
{
  "flakeHosts": ["gaming", "mypi"],
  "hosts": {
    "gaming": { "ssh": "bosko@gaming", "tailscaleIp": "100.1.1.1", "flakeHost": true, "arch": "x86_64-linux" },
    "mypi":   { "ssh": "bosko@mypi", "tailscaleIp": "100.2.2.2", "flakeHost": true, "arch": "aarch64-linux", "aliases": ["thepi"] },
    "oldpi":  { "ssh": "natty@oldpi", "tailscaleIp": "100.3.3.3", "flakeHost": false, "arch": "aarch64-linux" },
    "noip":   { "ssh": "bosko@noip", "flakeHost": false }
  }
}
JSON

# --- PATH shims ---------------------------------------------------------------
cat >"$SHIMS/nix" <<'SHIM'
#!/usr/bin/env bash
echo "nix $*" >>"$CALLS"
case "$1" in
  eval)
    [ -e "$FX/nix_eval_fail" ] && { echo "error: attribute missing" >&2; exit 1; }
    cat "$FX/expected" ;;
  build)
    [ -e "$FX/nix_build_fail" ] && { echo "error: build failed" >&2; exit 1; }
    case " $* " in
      *" --dry-run "*) echo "this derivation will be built:" >&2 ;;
      *) cat "$FX/built" ;;
    esac ;;
  *) echo "UNEXPECTED nix $*" >>"$CALLS"; exit 97 ;;
esac
SHIM
cat >"$SHIMS/git" <<'SHIM'
#!/usr/bin/env bash
echo "git $*" >>"$CALLS"
[ -e "$FX/git_status" ] && cat "$FX/git_status"
exit 0
SHIM
cat >"$SHIMS/ssh" <<'SHIM'
#!/usr/bin/env bash
echo "ssh $*" >>"$CALLS"
while [ "${1:-}" = "-o" ]; do shift 2; done
shift # the user@ip target
cmd="$*"
if [ -e "$FX/ssh_down" ]; then
  echo "ssh: connect to host 100.2.2.2 port 22: Connection timed out" >&2
  exit 255
fi
case "$cmd" in
  true) exit 0 ;;
  "readlink -f /run/current-system") cat "$FX/current" ;;
  "readlink -f /nix/var/nix/profiles/system") cat "$FX/profile" ;;
  "systemctl --failed --plain --no-legend") cat "$FX/failed" ;;
  "readlink -f /run/booted-system /run/booted-system/kernel /run/current-system/kernel "*) cat "$FX/booted" ;;
  "cat /proc/uptime") cat "$FX/uptime" ;;
  *) echo "UNEXPECTED ssh $cmd" >>"$CALLS"; exit 97 ;;
esac
SHIM
cat >"$SHIMS/uname" <<'SHIM'
#!/usr/bin/env bash
case "$1" in
  -m) echo "${FAKE_UNAME_M:-x86_64}" ;;
  -n) echo shimhost ;;
  *) echo Linux ;;
esac
SHIM
for p in ssh-keygen ssh-keyscan scp ping curl rsync sudo; do
  cat >"$SHIMS/$p" <<'SHIM'
#!/usr/bin/env bash
echo "POISON $(basename "$0") $*" >>"$CALLS"
exit 99
SHIM
done
chmod +x "$SHIMS"/*
export PATH="$SHIMS:$PATH" CALLS FX
export HOSTS_JSON="$TMP/hosts.json" PI_REPO="/repo" PI_BACKUP_ROOT="$TMP/bk" PI_ASSUME_BUILDER=yes

# --- harness -------------------------------------------------------------------
EXP="/nix/store/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa-nixos-system-mypi-26.11"
OLD="/nix/store/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb-nixos-system-mypi-26.11"
reset_fx() {
  rm -f "$FX"/*
  printf '%s\n' "$EXP" >"$FX/expected"
  printf '%s\n' "$EXP" >"$FX/built"
  printf '%s\n' "$EXP" >"$FX/current"
  printf '%s\n' "$EXP" >"$FX/profile"
  : >"$FX/failed"
  printf '%s\n' "$EXP" /nix/store/k1-linux/Image /nix/store/k1-linux/Image /nix/store/i1-initrd/initrd /nix/store/i1-initrd/initrd /nix/store/m1-modules /nix/store/m1-modules >"$FX/booted"
  echo "93784.52 12345.67" >"$FX/uptime"
}
pass=0 fail=0
OUT="" ERR="" RC=0
invoke() {
  : >"$CALLS"
  OUT="$(bash "$SH" "$@" 2>"$TMP/err")"; RC=$?
  ERR="$(cat "$TMP/err")"
  cat "$CALLS" >>"$ALL"
}
eq()    { if [ "$2" = "$3" ]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL: $1 -- got '$2', wanted '$3'"; fi; }
has()   { case "$2" in *"$3"*) pass=$((pass + 1)) ;; *) fail=$((fail + 1)); echo "FAIL: $1 -- lacks '$3' in: $2" ;; esac; }
lacks() { case "$2" in *"$3"*) fail=$((fail + 1)); echo "FAIL: $1 -- unexpectedly has '$3' in: $2" ;; *) pass=$((pass + 1)) ;; esac; }
nlines() { printf '%s\n' "$1" | grep -c "$2"; }

reset_fx
# --- usage ---------------------------------------------------------------------
invoke --help;                        eq "help rc" "$RC" 0;  has "help text" "$OUT" "Usage:"
invoke;                               eq "no args is a usage error" "$RC" 2
invoke bogus mypi;                    eq "unknown subcommand" "$RC" 2
invoke build;                         eq "missing host" "$RC" 2
invoke build mypi extra;              eq "extra positional" "$RC" 2
invoke build mypi --bogus;            eq "unknown flag" "$RC" 2
invoke cmd mypi --mode bogus;         eq "bad mode" "$RC" 2
invoke cmd mypi --mode;               eq "flag without value" "$RC" 2
invoke verify mypi --expect relative; eq "bad --expect" "$RC" 2
invoke verify mypi --expect /etc/passwd; eq "--expect must be a store path" "$RC" 2
invoke cmd mypi --ip -oProxyCommand=x; eq "option-looking --ip" "$RC" 2
invoke verify mypi --dry-run;         eq "--dry-run is build-only" "$RC" 2
invoke build mypi --mode boot;        eq "--mode is not for build" "$RC" 2
invoke build mypi --reboot;           eq "--reboot is cmd-only" "$RC" 2
invoke cmd mypi --expect "$EXP";      eq "--expect is verify-only" "$RC" 2
PI_ASSUME_BUILDER=maybe invoke build mypi; eq "bad PI_ASSUME_BUILDER" "$RC" 2

# --- refusals (exit 1, nothing built, nothing contacted) -----------------------------
invoke build gaming;                  eq "x86_64 host is not a Pi" "$RC" 1; has "x86 message" "$ERR" "not aarch64-linux"
invoke build noip;                    eq "host without an ip" "$RC" 1;      has "no ip message" "$ERR" "no tailscaleIp"
invoke build oldpi;                   eq "non-flake Pi is refused" "$RC" 1; has "non-flake message" "$ERR" "not a migrated flake host"
invoke build unknownpi --ip 100.9.9.9; eq "unregistered host + --ip is refused" "$RC" 1; has "unregistered message" "$ERR" "not a migrated flake host"
PI_ASSUME_BUILDER=no invoke build mypi
eq "builder without binfmt is refused" "$RC" 1; has "builder message" "$ERR" "gaming"; has "builder message says laptops" "$ERR" "laptops cannot"
eq "refused build never reaches nix" "$(nlines "$(cat "$CALLS")" '^nix')" 0

# --- build ---------------------------------------------------------------------
invoke build mypi
eq "build rc" "$RC" 0
has "build prints EXPECTED" "$OUT" "EXPECTED $EXP"
has "build prints BUILT" "$OUT" "BUILT $EXP"
has "eval targets the toplevel outPath" "$(cat "$CALLS")" "nix eval --raw /repo#nixosConfigurations.mypi.config.system.build.toplevel.outPath"
has "build flags" "$(cat "$CALLS")" "nix build /repo#nixosConfigurations.mypi.config.system.build.toplevel --no-link --print-out-paths"
lacks "real build is not a dry-run" "$(cat "$CALLS")" "--dry-run"
has "build warns about the long build" "$ERR" "background"

invoke build thepi
eq "alias resolves to the canonical host" "$RC" 0; has "alias build ref" "$(cat "$CALLS")" "nixosConfigurations.mypi."

invoke build mypi --dry-run
eq "dry-run rc" "$RC" 0
has "dry-run passes --dry-run to nix build" "$(cat "$CALLS")" "--dry-run"
has "dry-run still prints EXPECTED" "$OUT" "EXPECTED $EXP"
lacks "dry-run prints no BUILT line" "$OUT" "BUILT"
has "dry-run says nothing was written" "$OUT" "DRY-RUN"

echo " M hosts/mypi/configuration.nix" >"$FX/git_status"
invoke build mypi
eq "dirty tree warns but does not block" "$RC" 0; has "dirty warning" "$ERR" "WARN uncommitted-changes"; has "dirty warning lists the path" "$ERR" "hosts/mypi/configuration.nix"
has "git status is scoped to the host's files" "$(cat "$CALLS")" "status --porcelain -- hosts/mypi flake.nix flake.lock modules"
reset_fx

printf '%s\n' "$OLD" >"$FX/built"
invoke build mypi;                    eq "built path differs from evaluated" "$RC" 1; has "differs message" "$ERR" "different path"
reset_fx
touch "$FX/nix_build_fail"
invoke build mypi;                    eq "nix build failure propagates" "$RC" 1; has "build failure message" "$ERR" "nix build failed"
reset_fx
touch "$FX/nix_eval_fail"
invoke build mypi;                    eq "nix eval failure propagates" "$RC" 1; has "eval failure message" "$ERR" "nix eval failed"
eq "no build after a failed eval" "$(nlines "$(cat "$CALLS")" '^nix build')" 0
reset_fx

unset PI_ASSUME_BUILDER
FAKE_UNAME_M=aarch64 invoke build mypi
eq "native aarch64 machine passes the real builder probe" "$RC" 0
export PI_ASSUME_BUILDER=yes

# --- cmd -----------------------------------------------------------------------
WANT="nixos-rebuild switch --flake /repo#mypi --target-host bosko@100.2.2.2 --elevate sudo --ask-elevate-password"
invoke cmd mypi
eq "cmd rc" "$RC" 0
eq "cmd prints exactly one command line" "$(printf '%s\n' "$OUT" | grep -vc '^#')" 1
eq "cmd command is the canonical one" "$(printf '%s\n' "$OUT" | grep -v '^#')" "$WANT"
has "comment: own terminal" "$(printf '%s\n' "$OUT" | grep '^#')" "YOUR OWN terminal"
has "comment: no bang prefix" "$(printf '%s\n' "$OUT" | grep '^#')" "no '!' prefix"
has "comment: the alias" "$(printf '%s\n' "$OUT" | grep '^#')" "--ask-sudo-password"
eq "cmd contacts nothing" "$(cat "$CALLS")" ""
invoke cmd mypi --mode boot
eq "boot mode command" "$(printf '%s\n' "$OUT" | grep -v '^#')" "nixos-rebuild boot --flake /repo#mypi --target-host bosko@100.2.2.2 --elevate sudo --ask-elevate-password"
has "boot mode comment points at the reboot hand-off" "$OUT" "cmd mypi --reboot"
invoke cmd mypi --ip 100.7.7.7
has "ip override reaches --target-host" "$OUT" "--target-host bosko@100.7.7.7 "
invoke cmd mypi --reboot
eq "reboot hand-off is one command line" "$(printf '%s\n' "$OUT" | grep -vc '^#')" 1
eq "reboot hand-off command" "$(printf '%s\n' "$OUT" | grep -v '^#')" "ssh -t bosko@100.2.2.2 sudo systemctl reboot"
invoke cmd gaming;                    eq "cmd refuses a non-Pi" "$RC" 1
invoke cmd oldpi;                     eq "cmd refuses a non-flake Pi" "$RC" 1
PI_REPO='/re po' invoke cmd mypi;     eq "cmd refuses a repo path that needs quoting" "$RC" 1

# --- verify --------------------------------------------------------------------
invoke verify mypi
eq "verify PASS rc" "$RC" 0
has "current-system PASS" "$OUT" "PASS current-system: running $EXP == expected (nix eval)"
has "failed-units PASS" "$OUT" "PASS failed-units: none"
has "reboot PASS" "$OUT" "PASS reboot:"
has "booted-system INFO always printed" "$OUT" "INFO booted-system: $EXP"
has "uptime INFO" "$OUT" "INFO uptime: 1d 2h 3m"
has "RESULT PASS" "$OUT" "RESULT: PASS (3 passed)"
lacks "no FAIL on the green path" "$OUT" "FAIL"

invoke verify mypi --expect "$EXP"
eq "--expect rc" "$RC" 0; has "--expect source" "$OUT" "== expected (--expect)"
eq "--expect skips nix eval" "$(nlines "$(cat "$CALLS")" '^nix')" 0

invoke verify mypi --expect "$OLD"
eq "wrong --expect fails" "$RC" 1
has "mismatch FAIL" "$OUT" "FAIL current-system: running $EXP, expected $OLD"
has "mismatch hint" "$OUT" "not deployed yet, or built from a different commit - compare git HEAD"
has "RESULT FAIL" "$OUT" "RESULT: FAIL"

printf '%s\n' "$OLD" >"$FX/current"
printf '%s\n' "$OLD" >"$FX/profile"
invoke verify mypi
eq "not deployed yet" "$RC" 1; has "not deployed hint" "$OUT" "not deployed yet"

printf '%s\n' "$EXP" >"$FX/profile"
invoke verify mypi
eq "switch mode: profile has it but it is not running is a FAIL" "$RC" 1; has "activation message" "$OUT" "activation did not complete"
invoke verify mypi --mode boot
eq "boot mode: staged is a WARN, not a FAIL" "$RC" 0
has "staged WARN" "$OUT" "WARN current-system: staged, not running"
has "staged RESULT" "$OUT" "RESULT: PASS with 1 warning(s)"
reset_fx

printf 'foo.service loaded failed failed Some Description\nbar.mount loaded failed failed Another One\n' >"$FX/failed"
invoke verify mypi
eq "failed units fail the run" "$RC" 1
has "failed units are listed by name" "$OUT" "FAIL failed-units: foo.service,bar.mount"
lacks "unit descriptions are not printed" "$OUT" "Some Description"
reset_fx

printf '%s\n' "$EXP" /nix/store/k1-linux/Image /nix/store/k2-linux/Image /nix/store/i1-initrd/initrd /nix/store/i1-initrd/initrd /nix/store/m1-modules /nix/store/m2-modules >"$FX/booted"
invoke verify mypi
eq "kernel change is a WARN, exit 0" "$RC" 0
has "reboot pending WARN" "$OUT" "WARN reboot: reboot pending (kernel/initrd changed): kernel,kernel-modules differ"
has "booted-system INFO on WARN too" "$OUT" "INFO booted-system:"
has "RESULT with warning" "$OUT" "RESULT: PASS with 1 warning(s)"
reset_fx

printf '%s\n' "$EXP" /nix/store/k1 /nix/store/k1 /nix/store/i1 /nix/store/i2 /nix/store/m1 /nix/store/m1 >"$FX/booted"
invoke verify mypi
has "initrd change is a WARN" "$OUT" "reboot pending (kernel/initrd changed): initrd differ"
reset_fx

touch "$FX/ssh_down"
invoke verify mypi
eq "unreachable Pi fails" "$RC" 1
has "unreachable FAIL" "$OUT" "FAIL ssh: cannot reach bosko@100.2.2.2: ssh: connect to host"
has "unreachable hint names ssh-keygen -R" "$OUT" "ssh-keygen -R 100.2.2.2"
has "RESULT FAIL when unreachable" "$OUT" "RESULT: FAIL"
reset_fx

touch "$FX/nix_eval_fail"
invoke verify mypi
eq "no expected toplevel is a FAIL" "$RC" 1; has "eval-failed message" "$OUT" "nix eval of the expected toplevel failed"
invoke verify mypi --expect "$EXP"
eq "--expect works without nix eval" "$RC" 0
reset_fx

invoke verify gaming;                 eq "verify refuses a non-Pi" "$RC" 1
invoke verify oldpi;                  eq "verify refuses a non-flake Pi" "$RC" 1

# --- safety: nothing outside the shims was reached, nothing privileged ran --------
eq "no poison shim was called" "$(nlines "$(cat "$ALL")" '^POISON')" 0
eq "no unexpected shim call" "$(nlines "$(cat "$ALL")" '^UNEXPECTED')" 0
eq "no ssh call carried sudo" "$(nlines "$(cat "$ALL")" '^ssh .*sudo')" 0
eq "every ssh call is BatchMode" "$(nlines "$(cat "$ALL")" '^ssh ')" "$(nlines "$(cat "$ALL")" '^ssh -o BatchMode=yes ')"

echo "pi-deploy.test.sh: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
