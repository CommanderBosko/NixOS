#!/usr/bin/env bash
# stage-remote.sh — route B: flash from ANOTHER machine (one that has the SD/USB
# reader, e.g. natalie-laptop whose USB "Multiple Card Reader" showed up as /dev/sda).
# Copies the image, flash-pi-media.sh and the seed files into a private temp dir on
# that machine, optionally runs the READ-ONLY device checks there, then PRINTS the two
# commands the USER must run: the sudo flash, and the cleanup. It never runs sudo or
# a remote delete itself.
#
# Usage: stage-remote.sh <host> <flasher> <image> <keydir> [tailscaled.state]
#                        [--device DEV] [--dry-run]
#   <host>      the Pi being flashed (name/alias from .claude/hosts.json; only a label)
#   <flasher>   the machine with the card reader: a hosts.json name/alias, or user@host
#   <image>     local .img.zst / .img (e.g. from build-image.sh)
#   <keydir>    local dir with ssh_host_ed25519_key + .pub (see gen-host-key.sh)
#   [state]     optional local tailscaled.state to seed
#   --device D  the device on the flasher (confirmed with lsblk THERE, e.g. /dev/sda):
#               runs 'flash-pi-media.sh --check D' and '--plan ...' remotely (no root,
#               writes nothing) and puts D into the flash hand-off. Without it the
#               hand-off carries a <DEVICE> placeholder.
#   --dry-run   print the planned ssh/scp commands and hand-offs; run nothing
#   -h, --help  this text
#
# What lands on the flasher: a 0700 dir /tmp/pi-flash.XXXXXX holding the image, the
# script, keys/ (the PRIVATE host key!) and optionally tailscaled.state. The cleanup
# hand-off removes it; run it even if you abandon the flash.
#
# Exit codes: 0 staged (checks passed) and hand-offs printed; 1 a local file is missing,
# ssh/scp failed, or the remote check/plan refused; 2 usage error.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/../../../.." && pwd)"
# shellcheck source=../../../lib/pi-host.sh
source "$REPO/.claude/lib/pi-host.sh"
FLASH_SH="$HERE/flash-pi-media.sh"
SSH_OPTS=(-o BatchMode=yes -o ConnectTimeout=10)
REMOTE_DIR="" # set as soon as the remote temp dir exists, so a failure can still hand off its cleanup

usage() {
  awk '/^set -euo/ { exit } NR > 1 { sub(/^# ?/, ""); print }' "${BASH_SOURCE[0]}"
}

usage_err() {
  echo "ERROR: $*" >&2
  usage >&2
  exit 2
}

stage_cmds() { # print one line per planned command (dry-run) with <REMOTE_DIR> as the dir
  local d=$1
  echo "ssh $TARGET 'umask 077; mktemp -d /tmp/pi-flash.XXXXXX'"
  echo "ssh $TARGET 'mkdir -m 700 $d/keys'"
  echo "scp $IMAGE $TARGET:$d/$IMG_NAME"
  echo "scp $FLASH_SH $TARGET:$d/flash-pi-media.sh"
  echo "scp $KEYDIR/ssh_host_ed25519_key $KEYDIR/ssh_host_ed25519_key.pub $TARGET:$d/keys/"
  if [ -n "$STATE" ]; then echo "scp $STATE $TARGET:$d/tailscaled.state"; fi
  echo "ssh $TARGET 'stat -c %s $d/$IMG_NAME'   # size must equal the local file"
  if [ -n "$DEVICE" ]; then
    echo "ssh $TARGET 'bash $d/flash-pi-media.sh --check $DEVICE'   # read-only"
    echo "ssh $TARGET 'bash $d/flash-pi-media.sh --plan $DEVICE $d/$IMG_NAME $d/keys${STATE:+ $d/tailscaled.state}'   # read-only"
  fi
}

flash_cmd() { # <dir> <device-or-placeholder>
  echo "ssh -t $TARGET sudo bash $1/flash-pi-media.sh $2 $1/$IMG_NAME $1/keys${STATE:+ $1/tailscaled.state}"
}

print_handoffs() { # <dir> <flash-ok: 1|0> <device-checked-remotely: 1|0>
  local d=$1 ok=$2 checked=$3 dev=${DEVICE:-<DEVICE>}
  echo
  if [ "$ok" -eq 1 ]; then
    echo "================ HAND-OFF 1 of 2: flash (YOU run this in your own terminal) ================"
    echo "On $TARGET, lsblk shows which device is the card/stick: an empty reader slot has size 0."
    if [ -z "$DEVICE" ]; then
      echo "Replace <DEVICE> with the whole disk you confirmed (e.g. /dev/sda), then run the ONE command."
      echo "(Safer: re-run this script with --device <DEVICE> first so it runs the read-only check/plan there.)"
    elif [ "$checked" -eq 1 ]; then
      echo "Device $DEVICE passed the remote --check and --plan. Run the ONE command:"
    else
      echo "Device $DEVICE has NOT been checked (dry run). Run the ONE command:"
    fi
    echo
    echo "  $(flash_cmd "$d" "$dev")"
    echo
    echo "It asks for the sudo password on $TARGET, then makes you retype the device path to"
    echo "confirm the ERASE. dd conv=fsync shows ~1.4 GB/s, then sits silent for minutes while the"
    echo "real flush runs: normal, do not interrupt. Wait for 'DONE:', then remove the media."
    echo "Do NOT power the old card/disk at the same time as the new one."
  fi
  echo
  echo "================ HAND-OFF 2 of 2: cleanup (YOU run this afterwards, or if you abandon) ================"
  echo "The staged dir holds the PRIVATE host key${STATE:+ and the Tailscale state}; it must not stay on $TARGET:"
  echo
  echo "  ssh -t $TARGET rm -rf $d"
  echo
}

# shellcheck disable=SC2029 # client-side expansion is intended: $dir is regex-checked, $IMG_NAME is fixed
stage() {
  local dir remote_size local_size
  dir=$(ssh "${SSH_OPTS[@]}" "$TARGET" 'umask 077; mktemp -d /tmp/pi-flash.XXXXXX' | tail -n1) || return 1
  if ! [[ $dir =~ ^/[A-Za-z0-9._/-]+$ ]]; then
    echo "ERROR: $TARGET returned an unexpected directory name '$dir'; check /tmp/pi-flash.* there yourself" >&2
    return 1
  fi
  REMOTE_DIR=$dir
  ssh "${SSH_OPTS[@]}" "$TARGET" "mkdir -m 700 $dir/keys" || return 1
  echo "staging into $TARGET:$dir"
  scp -q "${SSH_OPTS[@]}" "$IMAGE" "$TARGET:$dir/$IMG_NAME" || return 1
  scp -q "${SSH_OPTS[@]}" "$FLASH_SH" "$TARGET:$dir/flash-pi-media.sh" || return 1
  scp -q "${SSH_OPTS[@]}" "$KEYDIR/ssh_host_ed25519_key" "$KEYDIR/ssh_host_ed25519_key.pub" "$TARGET:$dir/keys/" || return 1
  if [ -n "$STATE" ]; then
    scp -q "${SSH_OPTS[@]}" "$STATE" "$TARGET:$dir/tailscaled.state" || return 1
  fi
  local_size=$(stat -c %s "$IMAGE")
  remote_size=$(ssh "${SSH_OPTS[@]}" "$TARGET" "stat -c %s $dir/$IMG_NAME") || return 1
  if [ "$local_size" != "$remote_size" ]; then
    echo "ERROR: copied image is $remote_size bytes on $TARGET but $local_size locally (truncated copy?)" >&2
    return 1
  fi
  echo "PASS: image copied intact ($local_size bytes)"
  return 0
}

# shellcheck disable=SC2029 # client-side expansion is intended: $DEVICE and the dir are regex-whitelisted
remote_checks() { # read-only: --check, then --plan (which also proves the tools are installed there)
  local d=$REMOTE_DIR
  echo "--- remote --check $DEVICE on $TARGET (read-only)"
  ssh "${SSH_OPTS[@]}" "$TARGET" "bash $d/flash-pi-media.sh --check $DEVICE" || return 1
  echo "--- remote --plan on $TARGET (read-only)"
  ssh "${SSH_OPTS[@]}" "$TARGET" "bash $d/flash-pi-media.sh --plan $DEVICE $d/$IMG_NAME $d/keys${STATE:+ $d/tailscaled.state}" || return 1
}

main() {
  local host="" flasher="" dry=0 canon
  local -a pos=()
  IMAGE="" KEYDIR="" STATE="" DEVICE="" TARGET="" IMG_NAME=""
  while [ $# -gt 0 ]; do
    case $1 in
      -h | --help)
        usage
        exit 0
        ;;
      --dry-run) dry=1 ;;
      --device)
        [ $# -ge 2 ] || usage_err "--device needs a value"
        DEVICE=$2
        shift
        ;;
      -*) usage_err "unknown option $1" ;;
      *) pos+=("$1") ;;
    esac
    shift
  done
  [ ${#pos[@]} -ge 4 ] && [ ${#pos[@]} -le 5 ] || usage_err "want <host> <flasher> <image> <keydir> [tailscaled.state]"
  host=${pos[0]}
  flasher=${pos[1]}
  IMAGE=${pos[2]}
  KEYDIR=${pos[3]}
  STATE=${pos[4]:-}

  # values that end up inside a remote shell command line are whitelisted, not quoted
  [ -z "$DEVICE" ] || [[ $DEVICE =~ ^/dev/[A-Za-z0-9._/-]+$ ]] || usage_err "--device '$DEVICE' is not a plain /dev path"
  canon=$(hosts_canonical "$flasher")
  if [ -n "$canon" ]; then TARGET=$(hosts_ssh "$canon"); else TARGET=$flasher; fi
  [[ $TARGET =~ ^[A-Za-z0-9._][A-Za-z0-9._@-]*$ ]] || usage_err "flasher '$flasher' does not resolve to a plain [user@]host ssh target"
  canon=$(hosts_canonical "$host")
  PI_NAME=${canon:-$host}

  # local inputs: paths only, contents are never read or printed
  [ -f "$IMAGE" ] || pi_die "no image $IMAGE"
  case $IMAGE in
    *.img.zst | *.zst) IMG_NAME=image.img.zst ;;
    *.img) IMG_NAME=image.img ;;
    *) pi_die "$IMAGE is neither a .img.zst nor a raw .img" ;;
  esac
  [ -f "$KEYDIR/ssh_host_ed25519_key" ] && [ -f "$KEYDIR/ssh_host_ed25519_key.pub" ] ||
    pi_die "host key pair missing in $KEYDIR (gen-host-key.sh $PI_NAME makes one)"
  [ -z "$STATE" ] || [ -f "$STATE" ] || pi_die "no tailscale state file $STATE"
  [ -f "$FLASH_SH" ] || pi_die "flash-pi-media.sh missing next to this script ($FLASH_SH)"

  if [ "$dry" -eq 1 ]; then
    echo "DRY RUN: nothing is executed. Planned commands for flashing $PI_NAME from $TARGET:"
    stage_cmds "<REMOTE_DIR>"
    print_handoffs "<REMOTE_DIR>" 1 0
    exit 0
  fi

  if ! stage; then
    echo "ERROR: staging to $TARGET failed." >&2
    if [ -n "$REMOTE_DIR" ]; then print_handoffs "$REMOTE_DIR" 0 0; fi
    exit 1
  fi
  if [ -n "$DEVICE" ] && ! remote_checks; then
    echo "ERROR: the remote device check/plan refused $DEVICE; nothing was written." >&2
    print_handoffs "$REMOTE_DIR" 0 0
    exit 1
  fi
  echo "STAGED: $TARGET:$REMOTE_DIR"
  if [ -n "$DEVICE" ]; then print_handoffs "$REMOTE_DIR" 1 1; else print_handoffs "$REMOTE_DIR" 1 0; fi
}

# Run only when executed; sourcing (a test) just defines the functions.
if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
  main "$@"
fi
