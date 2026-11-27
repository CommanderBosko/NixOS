#!/usr/bin/env bash
#
# freeze-snapshot.sh - stop a service, snapshot its state directory, power off.
#
# SELF-CONTAINED and meant to run AS ROOT ON THE PI that is being migrated.
# The pi-cutover skill only stages this file in the login user's home and hands
# the user ONE command to run (sudo needs a TTY the skill does not have). It
# sources nothing from the repo on purpose: the old Pi has no checkout.
#
# What it does, in order:
#   1. validate arguments; require root unless --dry-run (before any change)
#   2. systemctl stop each --unit      (the freeze: nothing writes state now)
#   3. cp -a <state-dir>/. <dest>/     (dest is created 0700)
#   4. write <dest>/SHA256SUMS (relative paths), then re-verify the copy against
#      the sums AND the source against the sums
#   5. chown -R <owner>: <dest>        (so the login user can scp it off)
#   6. shutdown -h +N                  (skipped with --no-shutdown)
# If anything fails after step 2, the units it stopped are started again, so a
# failed run leaves the Pi serving. It prints names, sizes and hashes only,
# never file contents.
#
# Usage:
#   sudo bash freeze-snapshot.sh --unit U [--unit U2 ...] --state-dir D --dest DIR
#        [--owner USER] [--no-shutdown] [--shutdown-minutes N] [--dry-run]
#
#   --unit U               systemd unit to stop (repeatable)
#   --state-dir D          absolute path of the service's state directory
#   --dest DIR             absolute path for the snapshot; must not exist (or be
#                          empty) and its parent must already exist
#   --owner USER           login user that will scp the snapshot off (default
#                          $SUDO_USER; refused when neither is set, or if root)
#   --no-shutdown          stop and snapshot, but leave the Pi running
#   --shutdown-minutes N   delay before power-off (default 1, at least 1)
#   --dry-run              print the plan and change nothing (no root needed)
#   -h, --help             this text
#
# Exit codes: 0 ok, 1 a check or step failed / refused, 2 usage error.

set -euo pipefail
umask 077

PROG="freeze-snapshot.sh"

usage() {
  sed -n '/^# Usage:/,/^# Exit codes/p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}
die() { echo "ERROR: $*" >&2; exit 1; }
usage_die() { echo "ERROR: $*" >&2; echo "Try: bash $PROG --help" >&2; exit 2; }
is_uint() { case "$1" in '' | *[!0-9]*) return 1 ;; *) return 0 ;; esac; }

UNITS=() STATE_DIR="" DEST="" OWNER="" SHUTDOWN=1 MINUTES=1 DRY=0
while [ $# -gt 0 ]; do
  case "$1" in
    --unit) [ $# -ge 2 ] || usage_die "--unit needs a value"; UNITS+=("$2"); shift 2 ;;
    --state-dir) [ $# -ge 2 ] || usage_die "--state-dir needs a value"; STATE_DIR="$2"; shift 2 ;;
    --dest) [ $# -ge 2 ] || usage_die "--dest needs a value"; DEST="$2"; shift 2 ;;
    --owner) [ $# -ge 2 ] || usage_die "--owner needs a value"; OWNER="$2"; shift 2 ;;
    --no-shutdown) SHUTDOWN=0; shift ;;
    --shutdown-minutes) [ $# -ge 2 ] || usage_die "--shutdown-minutes needs a value"; MINUTES="$2"; shift 2 ;;
    --dry-run) DRY=1; shift ;;
    -h | --help) usage; exit 0 ;;
    *) usage_die "unknown argument: $1" ;;
  esac
done

[ "${#UNITS[@]}" -gt 0 ] || usage_die "--unit is required"
[ -n "$STATE_DIR" ] || usage_die "--state-dir is required"
[ -n "$DEST" ] || usage_die "--dest is required"
for u in "${UNITS[@]}"; do
  case "$u" in *[!A-Za-z0-9:_.@-]*) usage_die "odd characters in unit name: $u" ;; esac
done
case "$STATE_DIR" in /*) ;; *) usage_die "--state-dir must be an absolute path" ;; esac
case "$DEST" in /*) ;; *) usage_die "--dest must be an absolute path" ;; esac
STATE_DIR="${STATE_DIR%/}"
DEST="${DEST%/}"
[ -n "$STATE_DIR" ] || usage_die "refusing / as the state dir"
[ -n "$DEST" ] || usage_die "refusing / as the destination"
is_uint "$MINUTES" && [ "$MINUTES" -ge 1 ] || usage_die "--shutdown-minutes must be a whole number of at least 1"

[ -n "$OWNER" ] || OWNER="${SUDO_USER:-}"
[ -n "$OWNER" ] || usage_die "no --owner and SUDO_USER is empty: run it via sudo or pass --owner (the login user that will scp the snapshot off)"
case "$OWNER" in *:* | *[!A-Za-z0-9._-]*) usage_die "--owner takes a plain user name, got: $OWNER" ;; esac
[ "$OWNER" != "root" ] || usage_die "owner must be the login user that will scp the snapshot, not root"
id -u "$OWNER" >/dev/null 2>&1 || usage_die "unknown user: $OWNER"

[ -d "$STATE_DIR" ] || die "state dir not found: $STATE_DIR"
DEST_PARENT="$(dirname "$DEST")"
[ -d "$DEST_PARENT" ] || die "parent of --dest does not exist: $DEST_PARENT (create it as the login user first; this script will not create root-owned parents)"
if [ -e "$DEST" ] || [ -L "$DEST" ]; then
  [ -d "$DEST" ] && [ ! -L "$DEST" ] || die "--dest exists and is not a directory: $DEST"
  [ -z "$(ls -A "$DEST" 2>/dev/null)" ] || die "--dest is not empty: $DEST (move it aside; a snapshot never overwrites another)"
fi
STATE_REAL="$(cd "$STATE_DIR" && pwd -P)"
DEST_REAL="$(cd "$DEST_PARENT" && pwd -P)/$(basename "$DEST")"
case "$DEST_REAL/" in "$STATE_REAL"/*) die "--dest must not be inside --state-dir" ;; esac

if [ "$DRY" -eq 0 ] && [ "$(id -u)" -ne 0 ]; then
  die "must run as root (sudo bash $PROG ...). Nothing was changed."
fi

echo "freeze-snapshot on $(uname -n): units=${UNITS[*]} state=$STATE_DIR dest=$DEST owner=$OWNER"
if [ "$SHUTDOWN" -eq 1 ]; then
  SHUTDOWN_PLAN="shutdown -h +$MINUTES"
else
  SHUTDOWN_PLAN="(skipped: --no-shutdown)"
fi
if [ "$DRY" -eq 1 ]; then
  echo "DRY RUN: nothing will be changed. Planned steps:"
  for u in "${UNITS[@]}"; do echo "  1. systemctl stop $u"; done
  echo "  2. cp -a $STATE_DIR/. $DEST/"
  echo "  3. sha256sum every file under $DEST > $DEST/SHA256SUMS (relative paths), verify copy and source"
  echo "  4. chown -R $OWNER: $DEST; chmod -R u+rwX,go-rwx $DEST"
  echo "  5. $SHUTDOWN_PLAN"
  echo "DRY RUN done."
  exit 0
fi

# Anything that stopped a running unit and then failed must not leave the Pi
# silent: start the units again (the state dir is only ever read here).
STOPPED=() DONE=0
cleanup() {
  local rc=$? u
  trap - EXIT
  if [ "$rc" -ne 0 ] && [ "$DONE" -eq 0 ] && [ "${#STOPPED[@]}" -gt 0 ]; then
    echo "FAILED (exit $rc) after stopping the service: starting it again so the Pi keeps serving." >&2
    for u in "${STOPPED[@]}"; do
      systemctl start "$u" || echo "WARN: could not restart $u, start it by hand: systemctl start $u" >&2
    done
    [ -d "$DEST" ] && echo "NOTE: a partial snapshot may remain at $DEST; move it aside before retrying." >&2
  fi
  exit "$rc"
}
trap cleanup EXIT

if [ -n "$(find "$STATE_DIR" -name SHA256SUMS -print -quit 2>/dev/null)" ]; then
  die "the state dir already contains a file named SHA256SUMS; refusing (it would be confused with the manifest)"
fi

echo "==> freezing"
for u in "${UNITS[@]}"; do
  if systemctl is-active --quiet "$u"; then STOPPED+=("$u"); fi
  echo "stopping $u"
  systemctl stop "$u"
done

echo "==> copying $STATE_DIR -> $DEST"
mkdir -p "$DEST"
chmod 0700 "$DEST"
cp -a -- "$STATE_DIR"/. "$DEST"/

echo "==> writing and verifying SHA256SUMS"
sums="$(cd "$DEST" && find . -type f ! -name SHA256SUMS -printf '%P\0' | LC_ALL=C sort -z | xargs -0 -r sha256sum --)"
printf '%s\n' "$sums" >"$DEST/SHA256SUMS"
n_sums="$(wc -l <"$DEST/SHA256SUMS")"
n_src="$(find "$STATE_DIR" -type f -printf '.' | wc -c)"
[ "$n_sums" -eq "$n_src" ] || die "file count mismatch: $n_src in $STATE_DIR, $n_sums in the snapshot"
[ "$n_sums" -gt 0 ] || die "the state dir holds no regular files; nothing to snapshot"
(cd "$DEST" && sha256sum --quiet -c SHA256SUMS) || die "the copy does not match its SHA256SUMS"
(cd "$STATE_DIR" && sha256sum --quiet -c "$DEST/SHA256SUMS") || die "the live state dir differs from the copy (is the unit really stopped?)"

chown -R "$OWNER:" "$DEST"
chmod -R u+rwX,go-rwx "$DEST"
DONE=1

total=0 shown=0
while IFS= read -r line; do
  hash="${line%% *}"
  name="${line:66}"
  size="$(stat -c %s -- "$DEST/$name")"
  total=$((total + size))
  if [ "$shown" -lt 50 ]; then
    printf '  %10s bytes  %s  %s\n' "$size" "${hash:0:16}" "$name"
    shown=$((shown + 1))
  fi
done <"$DEST/SHA256SUMS"
[ "$n_sums" -le 50 ] || echo "  ... and $((n_sums - 50)) more (see $DEST/SHA256SUMS)"
echo "snapshot: $n_sums files, $total bytes, verified against SHA256SUMS and the source; owner $OWNER"

if [ "$SHUTDOWN" -eq 1 ]; then
  echo "==> power-off scheduled in $MINUTES min (cancel with: shutdown -c)"
  echo "NOTE: do not let it fire before pull-verify-snapshot.sh has passed on the other machine."
  shutdown -h "+$MINUTES" "pi-cutover: state snapshot taken, powering off"
else
  echo "Pi left running (--no-shutdown). The service stays stopped until the Pi is halted or restarted: systemctl start <unit>"
fi
echo "OK: freeze-snapshot done."
