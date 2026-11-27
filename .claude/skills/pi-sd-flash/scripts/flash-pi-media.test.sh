#!/usr/bin/env bash
# Tests for flash-pi-media.sh. SAFE BY CONSTRUCTION:
#   - refuses to run as root, so flash mode is never reachable with privileges;
#   - real-machine cases are --check/--plan refusals only (read-only lsblk/findmnt);
#   - fixture cases source the script's functions behind lsblk/findmnt PATH shims;
#   - dd/mount/umount/blkid/install/udevadm/blockdev/zstd/cmp are call-recording shims
#     that FAIL if invoked, and every group asserts the call log stayed empty.
# Run: bash .claude/skills/pi-sd-flash/scripts/flash-pi-media.test.sh
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SH="$HERE/flash-pi-media.sh"

if [ "$(id -u)" -eq 0 ]; then
  echo "flash-pi-media.test.sh: refusing to run as root (flash mode must never be reachable with privileges from a test)"
  exit 1
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
FIX="$TMP/fix"
SHIMS="$TMP/shims"
CALLS="$TMP/calls.log"
mkdir -p "$FIX" "$SHIMS"

pass=0 fail=0 skip=0
ok() { if [ "$2" = "$3" ]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL: $1 -- got '$2', wanted '$3'"; fi; }
has() { # has <name> <text> <substring>
  case "$2" in *"$3"*) pass=$((pass + 1)) ;; *) fail=$((fail + 1)); echo "FAIL: $1 -- output lacks '$3': $2" ;; esac
}
lacks() { # lacks <name> <text> <substring>
  case "$2" in *"$3"*) fail=$((fail + 1)); echo "FAIL: $1 -- output unexpectedly has '$3': $2" ;; *) pass=$((pass + 1)) ;; esac
}
skipped() { skip=$((skip + 1)); echo "skip: $1"; }

# refuses <name> <substring> <cmd...>: exit 1, a line starting REFUSING:, no OK line, substring present
refuses() {
  local name=$1 want=$2 out rc
  shift 2
  out=$("$@" 2>&1)
  rc=$?
  ok "$name (rc)" "$rc" "1"
  if printf '%s\n' "$out" | grep -q '^REFUSING:'; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL: $name -- no REFUSING: line: $out"; fi
  lacks "$name (no OK line)" "$out" "OK: /dev"
  has "$name (message)" "$out" "$want"
}

# ---- shims -------------------------------------------------------------------
cat >"$SHIMS/lsblk" <<'SHIM'
#!/usr/bin/env bash
# lsblk shim: answers from $FIX files only; never touches a real device.
args=("$@")
field="" inv=""
for ((i = 0; i < ${#args[@]}; i++)); do
  a=${args[$i]}
  case $a in
    -*o)
      field=${args[$((i + 1))]}
      case $a in *s*) inv=.inv ;; esac
      ;;
  esac
done
dev=${args[${#args[@]} - 1]}
case $field in NAME,*) echo "NAME SIZE TYPE (fixture table for $dev)"; exit 0 ;; esac
key="$FIX/$(basename "$dev")$inv.${field//,/_}"
if [ -f "$key" ]; then cat "$key"; else echo "lsblk shim: no fixture $key" >&2; exit 99; fi
SHIM
cat >"$SHIMS/findmnt" <<'SHIM'
#!/usr/bin/env bash
cat "$FIX/root.source"
SHIM
for t in dd mount umount blkid install udevadm blockdev zstd cmp; do
  cat >"$SHIMS/$t" <<'SHIM'
#!/usr/bin/env bash
printf '%s %s\n' "$(basename "$0")" "$*" >>"$CALLS"
exit 99
SHIM
done
cat >"$SHIMS/ssh-keygen" <<'SHIM'
#!/usr/bin/env bash
# ssh-keygen shim: -y "derives" a public key; never generates anything.
echo "${SHIM_KEYGEN_OUT:-ssh-ed25519 AAAAmatch derived}"
SHIM
chmod +x "$SHIMS"/*
export FIX CALLS

# mkdev <name> <type> <rm> <tran> <ro> <size-bytes> [raw mountpoints text]
mkdev() {
  printf '%s\n' "$2" >"$FIX/$1.TYPE"
  printf '%s\n' "$3" >"$FIX/$1.RM"
  printf '%s\n' "$4" >"$FIX/$1.TRAN"
  printf '%s\n' "$5" >"$FIX/$1.RO"
  printf '%s\n' "$6" >"$FIX/$1.SIZE"
  printf '%s' "${7:-}" >"$FIX/$1.MOUNTPOINTS"
}
GiB=$((1024 * 1024 * 1024))
printf '/dev/fakeroot2\n' >"$FIX/root.source"
printf '/dev/fakeroot2 part\n/dev/fakeroot disk\n' >"$FIX/fakeroot2.inv.PATH_TYPE"

# sh_fn <function + args>: run a script function with the fixture shims first on PATH
sh_fn() { PATH="$SHIMS:$PATH" bash -c 'src=$1; shift; source "$src"; "$@"' flash-test "$SH" "$@" 2>&1; }
# sh_plan: same, with validate_dev's real-block-device test swapped for the fixture path
sh_plan() { PATH="$SHIMS:$PATH" bash -c 'src=$1; shift; source "$src"; validate_dev() { validate_props "$1"; }; "$@"' flash-test "$SH" "$@" 2>&1; }

# ---- inputs ------------------------------------------------------------------
IMG="$TMP/pi.img.zst"
printf '\050\265\057\375placeholder-not-a-real-image' >"$IMG"
RAW="$TMP/pi.img"
printf 'placeholder-raw-image' >"$RAW"
KEYS="$TMP/keys"
mkdir -p "$KEYS"
printf 'PLACEHOLDER-PRIVATE-NOT-A-KEY\n' >"$KEYS/ssh_host_ed25519_key"
printf 'ssh-ed25519 AAAAmatch placeholder\n' >"$KEYS/ssh_host_ed25519_key.pub"
STATE="$TMP/tailscaled.state"
printf '{"placeholder":true}\n' >"$STATE"

# ============================================================================
echo "--- real machine: read-only refusals"
refuses "--check nonexistent path" "not a block device" bash "$SH" --check /dev/this-device-does-not-exist
refuses "--check /dev/null" "not a block device" bash "$SH" --check /dev/null

rsrc=$(findmnt -no SOURCE / 2>/dev/null | head -n1)
rsrc=${rsrc%%\[*}
rdisk="" rpart=""
if [[ $rsrc == /dev/* ]]; then
  rdisk=$(lsblk -nsro PATH,TYPE "$rsrc" 2>/dev/null | awk '$2 == "disk" { print $1; exit }')
  rpart=$(lsblk -nsro PATH,TYPE "$rsrc" 2>/dev/null | awk '$2 == "part" { print $1; exit }')
fi
if [ -n "$rdisk" ] && [ -b "$rdisk" ]; then
  refuses "--check the disk holding /" "root filesystem" bash "$SH" --check "$rdisk"
else
  skipped "no /dev disk behind / on this machine"
fi
if [ -n "$rpart" ] && [ -b "$rpart" ]; then
  refuses "--check a partition of the root disk" "not a whole disk" bash "$SH" --check "$rpart"
else
  skipped "no partition behind / on this machine"
fi
# /dev/nvme0n1 and /dev/sda are internal disks on the dev machines; only assert when they
# exist AND really are internal (a USB stick that happens to be sda must not fail the suite).
for d in /dev/nvme0n1 /dev/sda; do
  if [ -b "$d" ]; then
    tran=$(lsblk -dno TRAN "$d" 2>/dev/null | tr -d ' ')
    rm=$(lsblk -dno RM "$d" 2>/dev/null | tr -d ' ')
    if [ "$tran" != usb ] && [ "$rm" != 1 ]; then
      refuses "--check internal disk $d" "REFUSING" bash "$SH" --check "$d"
    else
      skipped "$d is removable/USB here"
    fi
  else
    skipped "$d does not exist here"
  fi
done

echo "--- real machine: --plan / flash refusals, usage errors"
refuses "--plan missing image" "no image" bash "$SH" --plan /dev/null "$TMP/missing.img.zst" "$KEYS"
refuses "--plan missing key dir" "host key pair missing" bash "$SH" --plan /dev/null "$IMG" "$TMP/no-such-keys"
refuses "--plan unknown image extension" "neither a .img.zst nor a raw .img" bash "$SH" --plan /dev/null "$KEYS/ssh_host_ed25519_key.pub" "$KEYS"
printf 'not zstd data' >"$TMP/fake.img.zst"
refuses "--plan .zst without zstd magic" "zstd magic" bash "$SH" --plan /dev/null "$TMP/fake.img.zst" "$KEYS"
refuses "--plan missing tailscale state" "no tailscale state" bash "$SH" --plan /dev/null "$IMG" "$KEYS" "$TMP/no-state"

rm -f "$CALLS"
out=$(PATH="$SHIMS:$PATH" bash "$SH" /dev/null "$IMG" "$KEYS" "$STATE" 2>&1)
rc=$?
ok "flash as non-root (rc)" "$rc" "1"
has "flash as non-root (message)" "$out" "REFUSING: flash mode needs root"
has "flash as non-root (sudo hint)" "$out" "sudo"
ok "flash as non-root touched no write tool" "$([ -e "$CALLS" ] && echo called || echo none)" "none"

bash "$SH" >/dev/null 2>&1
ok "no arguments is a usage error" "$?" "2"
bash "$SH" --check >/dev/null 2>&1
ok "--check without a device is a usage error" "$?" "2"
bash "$SH" --plan /dev/null "$IMG" >/dev/null 2>&1
ok "--plan with too few arguments is a usage error" "$?" "2"
bash "$SH" --bogus >/dev/null 2>&1
ok "unknown option is a usage error" "$?" "2"
bash "$SH" /dev/null "$IMG" >/dev/null 2>&1
ok "flash with too few arguments is a usage error" "$?" "2"
out=$(bash "$SH" --help 2>&1)
ok "--help exits 0" "$?" "0"
has "--help shows usage" "$out" "Usage:"

# ============================================================================
echo "--- helpers"
ok "part_path sdX" "$(sh_fn part_path /dev/sdb 2)" "/dev/sdb2"
ok "part_path mmcblk" "$(sh_fn part_path /dev/mmcblk0 2)" "/dev/mmcblk0p2"
ok "part_path nvme" "$(sh_fn part_path /dev/nvme1n1 2)" "/dev/nvme1n1p2"
ok "image_kind .img.zst" "$(sh_fn image_kind /x/a.img.zst)" "zst"
ok "image_kind .zst" "$(sh_fn image_kind /x/a.zst)" "zst"
ok "image_kind .img" "$(sh_fn image_kind /x/a.img)" "raw"
ok "image_kind other" "$(sh_fn image_kind /x/a.iso)" "unknown"
for m in / /boot /boot/efi /nix /nix/store /home /home/bosko/sd /mnt/media /var/lib/x '[SWAP]'; do
  ok "classify_mount $m" "$(sh_fn classify_mount "$m")" "system"
done
ok "classify_mount /run/media" "$(sh_fn classify_mount /run/media/bosko/NIXOS_SD)" "auto"
ok "classify_mount /media" "$(sh_fn classify_mount /media/card)" "auto"
ok "classify_mount /mnt/sd" "$(sh_fn classify_mount /mnt/sd)" "other"
out=$(sh_fn need_tools no-such-tool-xyz)
ok "need_tools missing (rc)" "$(sh_fn need_tools no-such-tool-xyz >/dev/null 2>&1; echo $?)" "1"
has "need_tools names the missing tool" "$out" "no-such-tool-xyz"
# a PATH holding only sort, so zstd/blkid/udevadm are all "missing" regardless of this machine
mkdir -p "$TMP/minbin"
ln -s "$(command -v sort)" "$TMP/minbin/sort"
out=$(bash -c 'src=$1; shift; source "$src"; PATH=$1; need_tools zstd blkid udevadm lsblk' flash-test "$SH" "$TMP/minbin" 2>&1)
has "need_tools hints nix shell for zstd" "$out" "nix shell"
has "need_tools hint keeps PATH through sudo" "$out" "sudo env"
has "need_tools maps zstd" "$out" "nixpkgs#zstd"
has "need_tools maps util-linux" "$out" "nixpkgs#util-linux"
has "need_tools maps systemd" "$out" "nixpkgs#systemd"
ok "need_tools lists util-linux once" "$(printf '%s' "$out" | grep -o 'nixpkgs#util-linux' | wc -l | tr -d ' ')" "1"

# ============================================================================
echo "--- validate_props against fixtures"
rm -f "$CALLS"
mkdev fakeusb disk 1 usb 0 $((16 * GiB))
out=$(sh_fn validate_props /dev/fakeusb)
ok "good USB stick (rc)" "$(sh_fn validate_props /dev/fakeusb >/dev/null 2>&1; echo $?)" "0"
has "good USB stick OK line" "$out" "OK: /dev/fakeusb  16 GiB  tran=usb rm=1"

mkdev mmcblk0 disk 0 "" 0 $((32 * GiB))
ok "mmcblk is accepted without usb/rm" "$(sh_fn validate_props /dev/mmcblk0 >/dev/null 2>&1; echo $?)" "0"

mkdev sdint disk 0 sata 0 $((500 * GiB))
refuses "internal SATA disk" "not USB/removable/mmc" sh_fn validate_props /dev/sdint
mkdev tiny disk 1 usb 0 $((4 * GiB))
refuses "too small" "outside 8-512 GiB" sh_fn validate_props /dev/tiny
mkdev huge disk 1 usb 0 $((1024 * GiB))
refuses "too big" "outside 8-512 GiB" sh_fn validate_props /dev/huge
mkdev empty disk 1 usb 0 0
refuses "empty reader slot" "empty card-reader slot" sh_fn validate_props /dev/empty
mkdev locked disk 1 usb 1 $((16 * GiB))
refuses "read-only media" "read-only" sh_fn validate_props /dev/locked
mkdev apart part 1 usb 0 $((16 * GiB))
refuses "partition" "not a whole disk" sh_fn validate_props /dev/apart
mkdev aloop loop 0 "" 0 $((16 * GiB))
refuses "loop device" "not a whole disk" sh_fn validate_props /dev/aloop

# the disk holding / is refused even when it looks like perfect removable media
mkdev fakeroot disk 1 usb 0 $((64 * GiB))
refuses "USB-looking disk that holds /" "root filesystem" sh_fn validate_props /dev/fakeroot
printf '/dev/fakeroot2[/@]\n' >"$FIX/root.source"
refuses "btrfs-style root source still resolves" "root filesystem" sh_fn validate_props /dev/fakeroot
printf 'overlay\n' >"$FIX/root.source"
out=$(sh_fn validate_props /dev/fakeusb)
has "unresolvable / only warns" "$out" "WARN: could not map / to a disk"
has "unresolvable / still validates" "$out" "OK: /dev/fakeusb"
printf '/dev/fakeroot2\n' >"$FIX/root.source"

# mounts: system ones refused (including a '/' hiding behind another mountpoint, which
# the vendored exact-match test missed), non-automount mounts refused, automounts allowed
mkdev m1 disk 1 usb 0 $((16 * GiB)) '/'
refuses "mounted at /" "system mount (/)" sh_fn validate_props /dev/m1
mkdev m2 disk 1 usb 0 $((16 * GiB)) '/nix/store\x0a/'
refuses "multi-mount raw string with a system mount" "system mount (/nix/store)" sh_fn validate_props /dev/m2
mkdev m3 disk 1 usb 0 $((16 * GiB)) '/mnt/media'
refuses "mounted at /mnt/media" "system mount (/mnt/media)" sh_fn validate_props /dev/m3
mkdev m4 disk 1 usb 0 $((16 * GiB)) '/home/bosko/sd'
refuses "mounted under /home" "system mount" sh_fn validate_props /dev/m4
mkdev m5 disk 1 usb 0 $((16 * GiB)) '[SWAP]'
refuses "used as swap" "system mount ([SWAP])" sh_fn validate_props /dev/m5
mkdev m6 disk 1 usb 0 $((16 * GiB)) '/mnt/sd'
refuses "manual mount outside the automounter dirs" "unmount it yourself" sh_fn validate_props /dev/m6
mkdev m7 disk 1 usb 0 $((16 * GiB)) '/run/media/bosko/NIXOS_SD'
out=$(sh_fn validate_props /dev/m7)
ok "automount is accepted (rc)" "$(sh_fn validate_props /dev/m7 >/dev/null 2>&1; echo $?)" "0"
has "automount NOTE" "$out" "NOTE: /dev/m7 is mounted by a desktop automounter"
mkdev m8 disk 1 usb 0 $((16 * GiB)) '/run/media/bosko/My\x20Card\x0a/boot'
refuses "automount plus a system mount" "system mount (/boot)" sh_fn validate_props /dev/m8
mkdev m9 disk 1 usb 0 $((16 * GiB)) '/run/media/bosko/My\x20Card'
out=$(sh_fn validate_props /dev/m9)
has "escaped space in an automount path is decoded" "$out" "/run/media/bosko/My Card"
ok "validate_props wrote through no tool" "$([ -e "$CALLS" ] && echo called || echo none)" "none"

# ============================================================================
echo "--- --plan against fixtures (validate_dev swapped for validate_props)"
out=$(sh_plan cmd_plan /dev/fakeusb "$IMG" "$KEYS" "$STATE")
ok "plan zst + state (rc)" "$(sh_plan cmd_plan /dev/fakeusb "$IMG" "$KEYS" "$STATE" >/dev/null 2>&1; echo $?)" "0"
has "plan has the zstd|dd pipeline" "$out" "zstd -dc '$IMG' | dd of='/dev/fakeusb' bs=4M conv=fsync status=progress"
has "plan names the partition-2 label check" "$out" "label NIXOS_SD on /dev/fakeusb2"
has "plan seeds the host key" "$out" "/etc/ssh/ssh_host_ed25519_key (0600 root:root)"
has "plan seeds tailscale state" "$out" "/var/lib/tailscale/tailscaled.state (0600 root:root"
has "plan has the dd silence reminder" "$out" "1.4 GB/s"
has "plan has the two-nodes reminder" "$out" "Do NOT power the old card/disk at the same time"
has "plan says nothing was written" "$out" "nothing has been written"

out=$(sh_plan cmd_plan /dev/mmcblk0 "$RAW" "$KEYS")
has "plan raw image uses dd if=" "$out" "dd if='$RAW' of='/dev/mmcblk0' bs=4M conv=fsync status=progress"
lacks "plan raw image has no zstd step" "$out" "zstd -dc"
has "plan mmcblk partition naming" "$out" "label NIXOS_SD on /dev/mmcblk0p2"
has "plan without state says new tailnet device" "$out" "NEW tailnet device"
lacks "plan without state has no tailscale seed" "$out" "tailscaled.state ("

out=$(sh_plan cmd_plan /dev/fakeusb "$IMG" "$KEYS")
has "plan reports the key pair matches" "$out" "OK: host key pair matches"
SHIM_KEYGEN_OUT="ssh-ed25519 AAAAother derived" refuses "plan refuses a key pair that does not match" "does not match" sh_plan cmd_plan /dev/fakeusb "$IMG" "$KEYS"
printf 'ssh-rsa AAAA nope\n' >"$TMP/rsa.pub"
mkdir -p "$TMP/rsakeys"
cp "$KEYS/ssh_host_ed25519_key" "$TMP/rsakeys/"
cp "$TMP/rsa.pub" "$TMP/rsakeys/ssh_host_ed25519_key.pub"
refuses "plan refuses a non-ed25519 public key" "not an ssh-ed25519 public key" sh_plan cmd_plan /dev/fakeusb "$IMG" "$TMP/rsakeys"
refuses "plan refuses a bad device after valid inputs" "root filesystem" sh_plan cmd_plan /dev/fakeroot "$IMG" "$KEYS"
ok "planning called no write tool" "$([ -e "$CALLS" ] && echo called || echo none)" "none"

echo "flash-pi-media.test.sh: $pass passed, $fail failed, $skip skipped"
[ "$fail" -eq 0 ]
