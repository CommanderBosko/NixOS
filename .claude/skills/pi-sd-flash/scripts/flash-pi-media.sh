#!/usr/bin/env bash
# flash-pi-media.sh — flash a NixOS Raspberry Pi image onto removable media (SD card
# or USB stick) and seed the files that must never be in the Nix store.
#
# SELF-CONTAINED ON PURPOSE: no repo libraries are sourced, because stage-remote.sh
# copies this one file to other machines (bash + util-linux + coreutils + zstd only).
#
# Usage:
#   flash-pi-media.sh --check <dev>
#       Validate the device only. No root, writes nothing.
#   flash-pi-media.sh --plan <dev> <image> <keydir> [tailscaled.state]
#       Validate device + files + tools and print the exact steps flash mode WOULD
#       run. No root, writes nothing. Run this before every real flash.
#   sudo flash-pi-media.sh <dev> <image> <keydir> [tailscaled.state]
#       ERASE <dev>, write the image, seed the host key (and Tailscale state).
#   flash-pi-media.sh --help
#
#   <dev>      whole disk, e.g. /dev/sdb or /dev/mmcblk0 (never a partition)
#   <image>    NixOS sd-image: .img.zst (or .zst) or a raw .img
#   <keydir>   directory holding ssh_host_ed25519_key and ssh_host_ed25519_key.pub
#   [state]    optional tailscaled.state, to keep the old node's Tailscale identity
#
# Exit codes: 0 ok; 1 refused / a check failed (message starts "REFUSING:");
#             2 usage error.
#
# Guards (all enforced before anything is written): block device, whole disk only,
# not the disk holding /, USB/removable/mmcblk transport only, writable, 8-512 GiB,
# no system mount on it (/ /boot /nix /nix/store /home /mnt/media ...), any other
# mount refused unless it is a desktop automount (/run/media, /media), root check,
# tools present, typed device-path confirmation, NIXOS_SD label check after writing.
#
# Provenance: vendored from the hand-run flash-pi-sd.sh that flashed famdash and
# generalised. The write/seed path below is kept as close to that proven original as
# possible; it cannot be exercised without real media, so its tests (see
# flash-pi-media.test.sh) cover only the validation, planning and refusal paths.
set -euo pipefail

SELF="${BASH_SOURCE[0]}"
MNT="" # temp mount point, global so the EXIT trap can see it

die() {
  echo "REFUSING: $*" >&2
  exit 1
}

usage() { # the header comment, up to the provenance note
  awk '/^# Provenance/ { exit } NR > 1 { sub(/^# ?/, ""); print }' "$SELF"
}

usage_err() {
  echo "ERROR: $*" >&2
  usage >&2
  exit 2
}

# ---- tools -----------------------------------------------------------------

tool_pkg() { # which nixpkgs attribute provides <tool>
  case $1 in
    zstd) echo zstd ;;
    lsblk | blkid | mount | umount | findmnt | blockdev) echo util-linux ;;
    udevadm) echo systemd ;;
    cmp) echo diffutils ;;
    ssh-keygen) echo openssh ;;
    *) echo coreutils ;;
  esac
}

need_tools() { # refuse (before writing anything) if a tool is missing
  local t missing=() pkgs=()
  for t in "$@"; do
    command -v "$t" >/dev/null 2>&1 || missing+=("$t")
  done
  if ((${#missing[@]} == 0)); then return 0; fi
  for t in "${missing[@]}"; do pkgs+=("nixpkgs#$(tool_pkg "$t")"); done
  mapfile -t pkgs < <(printf '%s\n' "${pkgs[@]}" | sort -u)
  die "missing tool(s): ${missing[*]}. On a borrowed NixOS machine run this script inside: nix shell ${pkgs[*]} -c sudo env \"PATH=\$PATH\" bash $SELF <same arguments>"
}

# ---- device validation -----------------------------------------------------

dev_mounts() { # every mountpoint on <dev> or its children, one per line
  local raw
  raw=$(lsblk -nro MOUNTPOINTS "$1") || die "lsblk could not list the mounts of $1"
  # raw lsblk joins several mountpoints of one node with a literal \x0a and
  # escapes spaces as \x20 (e.g. "/nix/store\x0a/"); an exact-match test on the
  # raw string would miss a "/" hiding behind another mountpoint.
  printf '%s\n' "$raw" | sed -e 's/\\x0a/\n/g' -e 's/\\x20/ /g' | sed -e '/^[[:space:]]*$/d'
}

classify_mount() { # system | auto | other
  case $1 in
    / | /boot | /boot/* | /efi | /efi/* | /nix | /nix/* | /home | /home/* | /mnt/media | /mnt/media/* | \
      /usr | /usr/* | /var | /var/* | /etc | /etc/* | /opt | /opt/* | /srv | /srv/* | /root | /root/* | '[SWAP]')
      echo system ;;
    /run/media/* | /media/*) echo auto ;;
    *) echo other ;;
  esac
}

check_mounts() {
  local dev=$1 mounts m
  mounts=$(dev_mounts "$dev")
  while IFS= read -r m; do
    [[ -n $m ]] || continue
    case $(classify_mount "$m") in
      system) die "$dev holds a system mount ($m)" ;;
      auto) echo "NOTE: $dev is mounted by a desktop automounter at $m; flash mode unmounts it first" ;;
      *) die "$dev is mounted at $m: unmount it yourself first (umount '$m'). Only desktop automounts under /run/media or /media are unmounted for you" ;;
    esac
  done <<<"$mounts"
}

root_disks() { # whole disk(s) backing / (follows partitions, LUKS, LVM); fails if / is not on a /dev node
  local src
  src=$(findmnt -no SOURCE / | head -n1) || return 1
  src=${src%%\[*} # btrfs prints /dev/x[/@subvol]
  [[ $src == /dev/* ]] || return 1
  lsblk -nsro PATH,TYPE "$src" | awk '$2 == "disk" { print $1 }'
}

validate_props() { # every check that only needs lsblk/findmnt (so tests can fixture it)
  local dev=$1 name type rm ro tran size rds rd
  name=$(basename "$dev")
  type=$(lsblk -dno TYPE "$dev" | tr -d ' ')
  rm=$(lsblk -dno RM "$dev" | tr -d ' ')
  ro=$(lsblk -dno RO "$dev" | tr -d ' ')
  tran=$(lsblk -dno TRAN "$dev" | tr -d ' ')
  size=$(lsblk -bdno SIZE "$dev" | tr -d ' ')
  [[ $type == disk ]] || die "$dev is a '$type', not a whole disk"
  if rds=$(root_disks); then
    for rd in $rds; do
      if [[ $rd == "$dev" ]]; then die "$dev holds the root filesystem (/) of this machine"; fi
    done
  else
    echo "WARN: could not map / to a disk; relying on the mount checks alone" >&2
  fi
  if [[ $tran != usb && $rm != 1 && $name != mmcblk* ]]; then
    die "$dev is not USB/removable/mmc (tran='$tran' rm='$rm')"
  fi
  [[ $ro != 1 ]] || die "$dev is read-only (SD adapter write-protect switch?)"
  [[ $size =~ ^[0-9]+$ ]] || die "could not read the size of $dev"
  if ((size == 0)); then
    die "$dev reports 0 bytes: an empty card-reader slot? Insert the card and re-run lsblk"
  fi
  ((size >= 8 * 1024 ** 3 && size <= 512 * 1024 ** 3)) || die "$dev size $((size / 1024 ** 3)) GiB is outside 8-512 GiB"
  check_mounts "$dev"
  echo "OK: $dev  $((size / 1024 ** 3)) GiB  tran=$tran rm=$rm"
  lsblk -o NAME,SIZE,TYPE,TRAN,MODEL,LABEL,MOUNTPOINTS "$dev"
}

validate_dev() {
  local dev=$1
  [[ -b $dev ]] || die "$dev is not a block device"
  validate_props "$dev"
}

part_path() { # <disk> <n>: /dev/mmcblk0 -> /dev/mmcblk0p2, /dev/sdb -> /dev/sdb2
  if [[ $1 == *[0-9] ]]; then echo "${1}p$2"; else echo "$1$2"; fi
}

# ---- input validation ------------------------------------------------------

image_kind() {
  case $1 in
    *.img.zst | *.zst) echo zst ;;
    *.img) echo raw ;;
    *) echo unknown ;;
  esac
}

validate_inputs() {
  local img=$1 keydir=$2 ts=$3 kind derived pub
  [[ -f $img ]] || die "no image $img"
  kind=$(image_kind "$img")
  [[ $kind != unknown ]] || die "$img is neither a .img.zst nor a raw .img"
  [[ -s $img ]] || die "image $img is empty"
  if [[ $kind == zst ]]; then
    [[ $(head -c4 "$img" | od -An -tx1 | tr -d ' \n') == 28b52ffd ]] ||
      die "$img does not start with the zstd magic bytes (truncated download or not a zstd file)"
  fi
  [[ -f $keydir/ssh_host_ed25519_key && -f $keydir/ssh_host_ed25519_key.pub ]] ||
    die "host key pair missing in $keydir (need ssh_host_ed25519_key and ssh_host_ed25519_key.pub)"
  [[ -s $keydir/ssh_host_ed25519_key ]] || die "$keydir/ssh_host_ed25519_key is empty"
  [[ $(head -c11 "$keydir/ssh_host_ed25519_key.pub") == "ssh-ed25519" ]] ||
    die "$keydir/ssh_host_ed25519_key.pub is not an ssh-ed25519 public key"
  if command -v ssh-keygen >/dev/null 2>&1; then
    if derived=$(ssh-keygen -y -P "" -f "$keydir/ssh_host_ed25519_key" 2>/dev/null); then
      pub=$(cut -d' ' -f1,2 "$keydir/ssh_host_ed25519_key.pub")
      [[ $(printf '%s' "$derived" | cut -d' ' -f1,2) == "$pub" ]] ||
        die "ssh_host_ed25519_key does not match ssh_host_ed25519_key.pub in $keydir"
      echo "OK: host key pair matches"
    else
      echo "WARN: could not check that the host key pair matches (ssh-keygen -y failed)" >&2
    fi
  else
    echo "WARN: ssh-keygen not found; host key pair match not checked" >&2
  fi
  [[ -z $ts || -f $ts ]] || die "no tailscale state file $ts"
  [[ -z $ts || -s $ts ]] || die "tailscale state file $ts is empty"
  echo "OK: image ($kind), key pair${ts:+, tailscale state} present"
}

preflight() { # <kind>: every tool the flash path uses, checked BEFORE anything is written
  need_tools lsblk findmnt blkid dd mount umount sync install mktemp readlink udevadm blockdev cmp
  if [[ $1 == zst ]]; then need_tools zstd; fi
}

write_cmd() { # <kind> <img> <dev>: the exact write command, for the plan and the flash
  if [[ $1 == zst ]]; then
    echo "zstd -dc '$2' | dd of='$3' bs=4M conv=fsync status=progress"
  else
    echo "dd if='$2' of='$3' bs=4M conv=fsync status=progress"
  fi
}

DD_NOTE="dd conv=fsync: the progress counter races to ~1.4 GB/s (it is filling RAM cache), then sits SILENT for minutes while the real ~11 MB/s flush to the media happens. That is normal; do not interrupt it."

# ---- modes -----------------------------------------------------------------

cmd_plan() {
  local dev=$1 img=$2 keydir=$3 ts=${4:-} kind p2
  validate_inputs "$img" "$keydir" "$ts"
  kind=$(image_kind "$img")
  preflight "$kind"
  validate_dev "$dev"
  p2=$(part_path "$dev" 2)
  echo
  echo "PLAN for $dev (nothing has been written; flash mode would do exactly this):"
  echo "  1. ask you to retype '$dev' to confirm the ERASE (flash mode must run as root)"
  echo "  2. umount any desktop-automounted partition of $dev; refuse if one stays mounted"
  echo "  3. $(write_cmd "$kind" "$img" "$dev")"
  echo "     $DD_NOTE"
  echo "  4. sync; blockdev --rereadpt $dev; udevadm settle"
  echo "  5. require label NIXOS_SD on $p2, then mount it on a temp dir"
  echo "  6. seed $keydir/ssh_host_ed25519_key -> /etc/ssh/ssh_host_ed25519_key (0600 root:root)"
  echo "     seed $keydir/ssh_host_ed25519_key.pub -> /etc/ssh/ssh_host_ed25519_key.pub (0644 root:root)"
  if [[ -n $ts ]]; then
    echo "  7. seed $ts -> /var/lib/tailscale/tailscaled.state (0600 root:root, dir 0700)"
  else
    echo "  7. (no tailscale state given: the new node will register as a NEW tailnet device)"
  fi
  echo "  8. compare each seeded file with its source, sync, umount, remove the temp dir"
  echo "  9. remove the media. Do NOT power the old card/disk at the same time as this one."
}

cmd_flash() {
  local dev=$1 img=$2 keydir=$3 ts=${4:-} kind p2 again p
  [[ $EUID -eq 0 ]] || die "flash mode needs root: run with sudo (--check and --plan do not)"
  validate_inputs "$img" "$keydir" "$ts"
  kind=$(image_kind "$img")
  preflight "$kind"
  validate_dev "$dev"

  read -r -p "Type the device path again to ERASE it and flash: " again || again=""
  [[ $again == "$dev" ]] || die "confirmation did not match"

  # unmount anything on the media (desktop automounts only: check_mounts refused the rest)
  for p in $(lsblk -nro PATH,MOUNTPOINTS "$dev" | awk 'NF>1{print $1}'); do umount "$p"; done
  [[ -z $(dev_mounts "$dev") ]] || die "$dev still has a mounted partition after umount; not writing"

  echo "Writing $img to $dev"
  echo "NOTE: $DD_NOTE"
  if [[ $kind == zst ]]; then
    zstd -dc "$img" | dd of="$dev" bs=4M conv=fsync status=progress ||
      die "writing the image failed: $dev is now half-written; do NOT use it, re-run"
  else
    dd if="$img" of="$dev" bs=4M conv=fsync status=progress ||
      die "writing the image failed: $dev is now half-written; do NOT use it, re-run"
  fi
  sync
  blockdev --rereadpt "$dev" || true
  udevadm settle
  sleep 2

  p2=$(part_path "$dev" 2)
  [[ $(blkid -s LABEL -o value "$p2") == NIXOS_SD ]] || die "$p2 is not the NIXOS_SD root partition"
  MNT=$(mktemp -d)
  trap 'umount "${MNT:-}" 2>/dev/null || true; rmdir "${MNT:-}" 2>/dev/null || true' EXIT
  mount "$p2" "$MNT"

  install -d -m 755 -o root -g root "$MNT/etc/ssh"
  install -m 600 -o root -g root "$keydir/ssh_host_ed25519_key" "$MNT/etc/ssh/ssh_host_ed25519_key"
  install -m 644 -o root -g root "$keydir/ssh_host_ed25519_key.pub" "$MNT/etc/ssh/ssh_host_ed25519_key.pub"
  cmp -s "$keydir/ssh_host_ed25519_key" "$MNT/etc/ssh/ssh_host_ed25519_key" || die "seeded host key differs from $keydir"
  echo "seeded: /etc/ssh host key"
  if [[ -n $ts ]]; then
    install -d -m 700 -o root -g root "$MNT/var/lib/tailscale"
    install -m 600 -o root -g root "$ts" "$MNT/var/lib/tailscale/tailscaled.state"
    cmp -s "$ts" "$MNT/var/lib/tailscale/tailscaled.state" || die "seeded tailscale state differs from $ts"
    echo "seeded: /var/lib/tailscale/tailscaled.state"
  fi
  sync
  umount "$MNT"
  trap - EXIT
  rmdir "$MNT"
  echo "DONE: $dev is ready. Remove the media; do NOT power the old card/disk at the same time as this one."
}

resolve_dev() { # follow /dev/disk/by-id symlinks so partition naming and comparisons use the real node
  readlink -f -- "$1" 2>/dev/null || echo "$1"
}

main() {
  case ${1:-} in
    -h | --help)
      usage
      exit 0
      ;;
    --check)
      [[ $# -eq 2 ]] || usage_err "--check takes exactly one argument: <dev>"
      need_tools lsblk findmnt readlink
      validate_dev "$(resolve_dev "$2")"
      ;;
    --plan)
      [[ $# -eq 4 || $# -eq 5 ]] || usage_err "--plan takes <dev> <image> <keydir> [tailscaled.state]"
      need_tools lsblk findmnt readlink
      cmd_plan "$(resolve_dev "$2")" "$3" "$4" "${5:-}"
      ;;
    -*) usage_err "unknown option $1" ;;
    '') usage_err "missing arguments" ;;
    *)
      [[ $# -eq 3 || $# -eq 4 ]] || usage_err "flash mode takes <dev> <image> <keydir> [tailscaled.state]"
      # root first: nothing is read, resolved or written before this check
      [[ $EUID -eq 0 ]] || die "flash mode needs root: run with sudo (--check and --plan do not)"
      need_tools readlink
      cmd_flash "$(resolve_dev "$1")" "$2" "$3" "${4:-}"
      ;;
  esac
}

# Run only when executed; sourcing (the test does) just defines the functions.
if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
  main "$@"
fi
