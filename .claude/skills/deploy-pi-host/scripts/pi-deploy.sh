#!/usr/bin/env bash
#
# pi-deploy.sh — ship ONE committed config change to ONE already-migrated
# Raspberry Pi (the single-host path of the deploy-pi-host skill). It never
# deploys anything itself: 'build' only builds locally, 'cmd' only PRINTS the
# hand-off command, 'verify' only reads over ssh.
#
# Usage:
#   pi-deploy.sh build  <host> [--ip IP] [--dry-run]
#   pi-deploy.sh cmd    <host> [--ip IP] [--mode switch|boot] [--reboot]
#   pi-deploy.sh verify <host> [--ip IP] [--mode switch|boot] [--expect STORE_PATH]
#   pi-deploy.sh -h | --help
#
#   build   Pre-build <host>'s system toplevel on THIS machine, which must be
#           able to build aarch64 (gaming, via boot.binfmt.emulatedSystems; the
#           laptops cannot). Prints "EXPECTED <store path>" (nix eval), then,
#           unless --dry-run, builds it and prints "BUILT <store path>".
#           --dry-run passes --dry-run to nix build: it reports what would be
#           built or fetched and writes nothing. WARNs (never blocks) when the
#           files that feed the toplevel have uncommitted changes. A cold
#           build under QEMU can outlast a 10-minute tool timeout: run it in
#           the background.
#   cmd     Print the ONE hand-off command the user runs in their own terminal
#           (sudo needs a TTY, so no '!' prefix), preceded by '#' comment
#           line(s):
#             nixos-rebuild <mode> --flake <repo>#<host> --target-host <user@ip> --elevate sudo --ask-elevate-password
#           (the '--ask-sudo-password' alias is equivalent). --mode boot only
#           stages the generation; --reboot prints the follow-up reboot
#           hand-off (ssh -t <user@ip> sudo systemctl reboot) instead.
#   verify  Read-only ssh checks, one 'PASS|WARN|FAIL|INFO <check>: <detail>'
#           line each, then 'RESULT: ...':
#             current-system  /run/current-system equals the expected toplevel
#                             (--expect, else nix eval). In --mode boot, "profile
#                             has it but it is not running yet" is a WARN
#                             (staged), in switch mode it is a FAIL.
#             failed-units    systemctl --failed is empty (unit names listed)
#             reboot          booted-system kernel/initrd/kernel-modules equal
#                             current-system's, else WARN reboot pending
#             uptime          INFO only
#
# Options:
#   --ip IP          tailscale IP override (default: .tailscaleIp in hosts.json)
#   --mode M         switch (default, live) or boot (staged, needs a reboot);
#                    cmd and verify only
#   --expect PATH    verify against this toplevel (the EXPECTED line of build)
#                    instead of re-evaluating the flake; verify only
#   --dry-run        build only
#   --reboot         cmd only
#
# Environment:
#   PI_ASSUME_BUILDER=yes|no   TEST-ONLY hook: skip the real "can this machine
#                    build aarch64" probe (pi_builder_ok) and assume the answer.
#   plus pi-host.sh's: PI_REPO, PI_SSH_TIMEOUT, HOSTS_JSON, PI_BACKUP_ROOT.
#
# Exit codes: 0 ok (verify: no FAIL; WARNs still exit 0), 1 a check failed or
# the request was refused (not a Pi, not a flake host, builder cannot build
# aarch64, build failed, unreachable), 2 usage error.
#
# No 'set -e': verify must keep going past a failing check; build and cmd
# handle every error explicitly.
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
# shellcheck source=../../../lib/pi-host.sh
source "$REPO/.claude/lib/pi-host.sh"

usage() {
  cat <<'EOF'
Usage:
  pi-deploy.sh build  <host> [--ip IP] [--dry-run]
  pi-deploy.sh cmd    <host> [--ip IP] [--mode switch|boot] [--reboot]
  pi-deploy.sh verify <host> [--ip IP] [--mode switch|boot] [--expect STORE_PATH]

build    pre-build the toplevel on the aarch64-capable builder (gaming); prints EXPECTED <path>
cmd      print the single nixos-rebuild hand-off for the user's own terminal (--reboot: the reboot one)
verify   read-only ssh checks: running == expected, no failed units, reboot pending?, uptime

Exit codes: 0 ok, 1 check failed / refused, 2 usage error. See the header of this script.
EOF
}

usage_err() {
  echo "ERROR: $*" >&2
  echo "Try: pi-deploy.sh --help" >&2
  exit 2
}

# ---- arguments --------------------------------------------------------------
SUB="" HOST="" IP="" MODE="" EXPECT="" DRY=0 REBOOT=0
IP_SET=0 MODE_SET=0 EXPECT_SET=0
while [ $# -gt 0 ]; do
  case "$1" in
    -h | --help) usage; exit 0 ;;
    --ip | --mode | --expect)
      [ $# -ge 2 ] || usage_err "$1 needs a value"
      case "$1" in
        --ip) IP="$2"; IP_SET=1 ;;
        --mode) MODE="$2"; MODE_SET=1 ;;
        --expect) EXPECT="$2"; EXPECT_SET=1 ;;
      esac
      shift 2 ;;
    --dry-run) DRY=1; shift ;;
    --reboot) REBOOT=1; shift ;;
    -*) usage_err "unknown option: $1" ;;
    *)
      if [ -z "$SUB" ]; then SUB="$1"
      elif [ -z "$HOST" ]; then HOST="$1"
      else usage_err "unexpected argument: $1"
      fi
      shift ;;
  esac
done

case "$SUB" in
  build | cmd | verify) ;;
  "") usage_err "missing subcommand (build, cmd or verify)" ;;
  *) usage_err "unknown subcommand: $SUB (want build, cmd or verify)" ;;
esac
[ -n "$HOST" ] || usage_err "missing <host>"
[[ "$HOST" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || usage_err "bad host name: $HOST"
if [ "$IP_SET" = 1 ]; then
  [[ "$IP" =~ ^[A-Za-z0-9][A-Za-z0-9.:_-]*$ ]] || usage_err "bad --ip value: $IP"
fi
if [ "$MODE_SET" = 1 ]; then
  case "$MODE" in switch | boot) ;; *) usage_err "--mode must be switch or boot, got '$MODE'" ;; esac
fi
MODE="${MODE:-switch}"
if [ "$EXPECT_SET" = 1 ]; then
  [[ "$EXPECT" =~ ^/nix/store/[A-Za-z0-9+._?=-]+$ ]] || usage_err "--expect must be a /nix/store path, got '$EXPECT'"
fi
[ "$DRY" = 0 ] || [ "$SUB" = build ] || usage_err "--dry-run only applies to build"
[ "$REBOOT" = 0 ] || [ "$SUB" = cmd ] || usage_err "--reboot only applies to cmd"
[ "$EXPECT_SET" = 0 ] || [ "$SUB" = verify ] || usage_err "--expect only applies to verify"
[ "$MODE_SET" = 0 ] || [ "$SUB" != build ] || usage_err "--mode does not apply to build (it builds the same toplevel either way)"

# ---- shared checks ----------------------------------------------------------
require_flake_host() {
  hosts_flake_names | grep -qxF -- "$PI_NAME" ||
    pi_die "$PI_NAME is not in .flakeHosts of .claude/hosts.json, so it is not a migrated flake host (a first install is the pi-sd-flash + pi-cutover skills; register the host with new-host)"
}

safe_word() { [[ "$1" =~ ^[A-Za-z0-9._/+@:-]+$ ]]; }

# ---- build ------------------------------------------------------------------
refuse_builder() {
  pi_die "this machine ($(uname -n), $(uname -m)) cannot build aarch64-linux. Only the binfmt host (gaming: boot.binfmt.emulatedSystems = [ \"aarch64-linux\" ]) can; the laptops cannot. Run the build on gaming."
}

warn_uncommitted() {
  local st n
  # Everything that can change this Pi's toplevel. Nix flakes read tracked
  # working-tree edits but not untracked files, so both matter.
  st="$(git -C "$PI_REPO" status --porcelain -- "hosts/$PI_NAME" flake.nix flake.lock modules secrets .sops.yaml 2>/dev/null)" || return 0
  [ -n "$st" ] || return 0
  n="$(printf '%s\n' "$st" | wc -l | tr -d ' ')"
  echo "WARN uncommitted-changes: $n path(s) feeding $PI_NAME have uncommitted changes (first 5 below). The build includes tracked working-tree edits but NOT untracked files (git add new files); commit first so the deployed system matches git HEAD." >&2
  printf '%s\n' "$st" | head -n 5 | sed 's/^/     /' >&2
}

cmd_build() {
  case "${PI_ASSUME_BUILDER:-}" in
    yes) ;;
    no) refuse_builder ;;
    "") pi_builder_ok || refuse_builder ;;
    *) usage_err "PI_ASSUME_BUILDER must be 'yes' or 'no' (test-only hook)" ;;
  esac
  warn_uncommitted

  local ref expected built
  local -a args
  ref="$(pi_flake_ref toplevel)"
  expected="$(nix eval --raw "$ref.outPath")" ||
    pi_die "nix eval failed for $(pi_attr toplevel): is the nixosConfigurations.$PI_NAME entry in flake.nix, and are new files git-added?"
  [[ "$expected" =~ ^/nix/store/[^[:space:]]+$ ]] ||
    pi_die "nix eval returned something that is not a store path: '$expected'"
  echo "EXPECTED $expected"

  args=(build "$ref" --no-link --print-out-paths)
  if [ "$DRY" = 1 ]; then args+=(--dry-run); fi
  echo "NOTE: building $PI_NAME's toplevel (aarch64-linux) under QEMU/binfmt; a cold build can run past a 10-minute tool timeout, so run it in the background." >&2
  built="$(nix "${args[@]}")" || pi_die "nix build failed for $(pi_attr toplevel)"
  if [ "$DRY" = 1 ]; then
    echo "DRY-RUN nothing was built or written"
    return 0
  fi
  printf '%s\n' "$built" | grep -qxF -- "$expected" ||
    pi_die "nix build produced a different path than the evaluated toplevel ($expected); the tree changed during the build? Re-run build"
  echo "BUILT $expected"
}

# ---- cmd (print the hand-off; never run it) ---------------------------------
cmd_cmd() {
  if ! { safe_word "$PI_REPO" && safe_word "$PI_NAME" && safe_word "$PI_TARGET"; }; then
    pi_die "repo, host or target contains characters that would need shell quoting; refusing to print a command for it"
  fi
  if [ "$REBOOT" = 1 ]; then
    echo "# Hand-off: run this in YOUR OWN terminal (no '!' prefix: sudo needs a TTY to ask for the password). It reboots $PI_NAME; expect it back on the tailnet about 30 s after power-on, then re-run: pi-deploy.sh verify $PI_NAME"
    echo "ssh -t $PI_TARGET sudo systemctl reboot"
    return 0
  fi
  echo "# Hand-off ($MODE mode): run this in YOUR OWN terminal on the machine that ran 'build' (no '!' prefix: sudo needs a TTY to ask for the password). '--ask-sudo-password' is an equivalent alias for '--elevate sudo --ask-elevate-password'."
  if [ "$MODE" = boot ]; then
    echo "# boot mode only stages the generation; it is not running until the reboot hand-off: pi-deploy.sh cmd $PI_NAME --reboot"
  fi
  echo "nixos-rebuild $MODE --flake $PI_REPO#$PI_NAME --target-host $PI_TARGET --elevate sudo --ask-elevate-password"
}

# ---- verify (read-only) -----------------------------------------------------
NPASS=0 NWARN=0 NFAIL=0
say() { # <PASS|WARN|FAIL|INFO> <check> <detail>
  printf '%s %s: %s\n' "$1" "$2" "$3"
  case "$1" in
    PASS) NPASS=$((NPASS + 1)) ;;
    WARN) NWARN=$((NWARN + 1)) ;;
    FAIL) NFAIL=$((NFAIL + 1)) ;;
  esac
}

finish() {
  if [ "$NFAIL" -gt 0 ]; then
    echo "RESULT: FAIL ($NFAIL failed, $NWARN warning(s), $NPASS passed)"
    exit 1
  elif [ "$NWARN" -gt 0 ]; then
    echo "RESULT: PASS with $NWARN warning(s) ($NPASS passed)"
    exit 0
  fi
  echo "RESULT: PASS ($NPASS passed)"
  exit 0
}

cmd_verify() {
  local err expected="" src cur prof out units secs up i name
  local -a P changed

  err="$(pi_ssh true 2>&1 >/dev/null)" || {
    say FAIL ssh "cannot reach $PI_TARGET: ${err%%$'\n'*}"
    say INFO hint "powered off or not on the tailnet yet (~30 s after power-on)? After a reflash, clear the stale host key: ssh-keygen -R $PI_IP"
    finish
  }

  # (1) running system == expected toplevel
  if [ "$EXPECT_SET" = 1 ]; then
    expected="$EXPECT"; src="--expect"
  else
    src="nix eval"
    expected="$(nix eval --raw "$(pi_flake_ref toplevel).outPath" 2>/dev/null)" || expected=""
  fi
  cur="$(pi_ssh readlink -f /run/current-system 2>/dev/null)" || cur=""
  if [ -z "$cur" ]; then
    say FAIL current-system "could not read /run/current-system on $PI_TARGET"
  elif [ -z "$expected" ]; then
    say FAIL current-system "running $cur, but nix eval of the expected toplevel failed (pass --expect <path from build>)"
  elif [ "$cur" = "$expected" ]; then
    say PASS current-system "running $cur == expected ($src)"
  else
    prof="$(pi_ssh readlink -f /nix/var/nix/profiles/system 2>/dev/null)" || prof=""
    if [ "$prof" = "$expected" ] && [ "$MODE" = boot ]; then
      say WARN current-system "staged, not running: the system profile is the expected toplevel but /run/current-system is still $cur (boot mode: reboot to activate)"
    elif [ "$prof" = "$expected" ]; then
      say FAIL current-system "running $cur, expected $expected; the system profile already has the expected toplevel, so activation did not complete (deployed with --mode boot? verify with --mode boot and reboot; otherwise re-run the hand-off)"
    else
      say FAIL current-system "running $cur, expected $expected - not deployed yet, or built from a different commit - compare git HEAD"
    fi
  fi

  # (2) no failed units
  if ! out="$(pi_ssh systemctl --failed --plain --no-legend 2>/dev/null)"; then
    say FAIL failed-units "could not run systemctl --failed on $PI_TARGET"
  else
    units="$(printf '%s\n' "$out" | awk 'NF { print $1 }' | paste -sd, -)"
    if [ -z "$units" ]; then
      say PASS failed-units "none"
    else
      say FAIL failed-units "$units"
    fi
  fi

  # (3) booted vs current: a switch changes /run/current-system but never /run/booted-system
  out="$(pi_ssh readlink -f /run/booted-system /run/booted-system/kernel /run/current-system/kernel /run/booted-system/initrd /run/current-system/initrd /run/booted-system/kernel-modules /run/current-system/kernel-modules 2>/dev/null)"
  mapfile -t P <<<"$out"
  if [ "${#P[@]}" -lt 7 ]; then
    say WARN reboot "could not compare booted-system with current-system"
  else
    changed=()
    i=1
    for name in kernel initrd kernel-modules; do
      [ "${P[i]}" = "${P[i + 1]}" ] || changed+=("$name")
      i=$((i + 2))
    done
    if [ "${#changed[@]}" -gt 0 ]; then
      say WARN reboot "reboot pending (kernel/initrd changed): $(printf '%s\n' "${changed[@]}" | paste -sd, -) differ between booted-system and current-system"
    else
      say PASS reboot "booted-system kernel, initrd and kernel-modules match current-system"
    fi
    say INFO booted-system "${P[0]} (/run/booted-system only moves on a reboot, so it stays the old path after a switch)"
  fi

  # (4) uptime
  up="$(pi_ssh cat /proc/uptime 2>/dev/null)" || up=""
  secs="${up%%.*}"
  if [[ "$secs" =~ ^[0-9]+$ ]]; then
    say INFO uptime "$((secs / 86400))d $(((secs % 86400) / 3600))h $(((secs % 3600) / 60))m"
  else
    say INFO uptime "unknown"
  fi

  finish
}

# ---- dispatch ---------------------------------------------------------------
pi_load "$HOST" "$IP"
pi_require_aarch64
require_flake_host
case "$SUB" in
  build) cmd_build ;;
  cmd) cmd_cmd ;;
  verify) cmd_verify ;;
esac
