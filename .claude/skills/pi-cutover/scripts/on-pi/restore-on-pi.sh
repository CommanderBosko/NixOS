#!/usr/bin/env bash
#
# restore-on-pi.sh - put snapshot files into a service's state dir on the NEW Pi.
#
# SELF-CONTAINED and meant to run AS ROOT ON THE NEW PI, from the directory the
# skill staged in the login user's home. The skill never runs it: it hands the
# user ONE sudo command. It sources nothing from the repo (the Pi has none).
#
# What it does, in order:
#   1. validate arguments; require root unless --dry-run (before any change)
#   2. systemctl stop each --unit
#   3. move any existing target aside as <file>.pre-restore-<UTC stamp>
#   4. install -m MODE -o USER -g GROUP each --src into <state-dir>, then check
#      the installed copy hashes the same as the source
#   5. systemctl start each --unit and wait for 'active' (up to --wait seconds)
#   6. optional --url check (curl run here, on the Pi; 2xx/3xx passes)
# A failure during steps 2-4 puts the moved-aside files back and restarts the
# units that were running. A failure at step 5 or 6 leaves the restored files in
# place (the problem may be the app, not the data) and prints how to undo it.
# It prints names, sizes and hashes only, never file contents.
#
# Usage:
#   sudo bash restore-on-pi.sh --unit U [--unit U2 ...] --state-dir D --src FILE [FILE...]
#        [--owner USER:GROUP] [--mode 0600] [--url URL] [--wait SECONDS] [--dry-run]
#
#   --unit U            systemd unit to stop and restart (repeatable)
#   --state-dir D       absolute path of the state directory; it must exist
#                       (start the unit once on a fresh Pi so it creates it)
#   --src FILE...       files to install; each lands in D under its own basename
#   --owner USER:GROUP  owner of the installed files (default: the owner of D)
#   --mode MODE         octal mode of the installed files (default 0600)
#   --url URL           after starting, curl this on the Pi until it answers 2xx/3xx
#   --wait SECONDS      how long to wait for the unit and the URL (default 30)
#   --dry-run           print the plan and change nothing (no root needed)
#   -h, --help          this text
#
# Exit codes: 0 ok, 1 a check or step failed / refused, 2 usage error.

set -euo pipefail
umask 077

PROG="restore-on-pi.sh"

usage() {
  sed -n '/^# Usage:/,/^# Exit codes/p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}
die() { echo "ERROR: $*" >&2; exit 1; }
usage_die() { echo "ERROR: $*" >&2; echo "Try: bash $PROG --help" >&2; exit 2; }
is_uint() { case "$1" in '' | *[!0-9]*) return 1 ;; *) return 0 ;; esac; }

UNITS=() STATE_DIR="" SRCS=() OWNER="" MODE="0600" URL="" WAIT=30 DRY=0
while [ $# -gt 0 ]; do
  case "$1" in
    --unit) [ $# -ge 2 ] || usage_die "--unit needs a value"; UNITS+=("$2"); shift 2 ;;
    --state-dir) [ $# -ge 2 ] || usage_die "--state-dir needs a value"; STATE_DIR="$2"; shift 2 ;;
    --src)
      shift
      { [ $# -gt 0 ] && [ "${1#-}" = "$1" ]; } || usage_die "--src needs at least one file"
      while [ $# -gt 0 ] && [ "${1#-}" = "$1" ]; do SRCS+=("$1"); shift; done
      ;;
    --owner) [ $# -ge 2 ] || usage_die "--owner needs a value"; OWNER="$2"; shift 2 ;;
    --mode) [ $# -ge 2 ] || usage_die "--mode needs a value"; MODE="$2"; shift 2 ;;
    --url) [ $# -ge 2 ] || usage_die "--url needs a value"; URL="$2"; shift 2 ;;
    --wait) [ $# -ge 2 ] || usage_die "--wait needs a value"; WAIT="$2"; shift 2 ;;
    --dry-run) DRY=1; shift ;;
    -h | --help) usage; exit 0 ;;
    *) usage_die "unknown argument: $1 (a --src file name must not start with '-'; use ./name)" ;;
  esac
done

[ "${#UNITS[@]}" -gt 0 ] || usage_die "--unit is required"
[ -n "$STATE_DIR" ] || usage_die "--state-dir is required"
[ "${#SRCS[@]}" -gt 0 ] || usage_die "--src is required"
for u in "${UNITS[@]}"; do
  case "$u" in *[!A-Za-z0-9:_.@-]*) usage_die "odd characters in unit name: $u" ;; esac
done
case "$STATE_DIR" in /*) ;; *) usage_die "--state-dir must be an absolute path" ;; esac
STATE_DIR="${STATE_DIR%/}"
[ -n "$STATE_DIR" ] || usage_die "refusing / as the state dir"
case "$MODE" in '' | *[!0-7]* | ?? | ?????*) usage_die "--mode must be 3 or 4 octal digits, got: $MODE" ;; esac
is_uint "$WAIT" || usage_die "--wait must be a whole number of seconds"
if [ -n "$URL" ]; then
  case "$URL" in http://* | https://*) ;; *) usage_die "--url must start with http:// or https://" ;; esac
  case "$URL" in *[[:space:]]*) usage_die "--url must not contain whitespace" ;; esac
fi

[ -d "$STATE_DIR" ] || die "state dir not found: $STATE_DIR (start the unit once on a fresh Pi so it creates it, then retry)"
[ -n "$OWNER" ] || OWNER="$(stat -c '%U:%G' -- "$STATE_DIR")"
case "$OWNER" in ?*:?*) ;; *) usage_die "--owner must look like USER:GROUP, got: $OWNER" ;; esac
OWNER_U="${OWNER%%:*}" OWNER_G="${OWNER#*:}"
id -u "$OWNER_U" >/dev/null 2>&1 || die "unknown user: $OWNER_U"
getent group "$OWNER_G" >/dev/null 2>&1 || die "unknown group: $OWNER_G"

TARGETS=()
for s in "${SRCS[@]}"; do
  [ -f "$s" ] && [ -r "$s" ] || die "source is not a readable regular file: $s"
  t="$STATE_DIR/$(basename -- "$s")"
  for seen in "${TARGETS[@]}"; do [ "$seen" != "$t" ] || die "two --src files share the name $(basename -- "$s")"; done
  TARGETS+=("$t")
done

if [ "$DRY" -eq 0 ] && [ "$(id -u)" -ne 0 ]; then
  die "must run as root (sudo bash $PROG ...). Nothing was changed."
fi

echo "restore-on-pi on $(uname -n): units=${UNITS[*]} state=$STATE_DIR owner=$OWNER mode=$MODE files=${#SRCS[@]}"
if [ "$DRY" -eq 1 ]; then
  echo "DRY RUN: nothing will be changed. Planned steps:"
  for u in "${UNITS[@]}"; do echo "  1. systemctl stop $u"; done
  for i in "${!SRCS[@]}"; do
    echo "  2. mv -- ${TARGETS[$i]} ${TARGETS[$i]}.pre-restore-<UTC stamp>   (only if it exists)"
    echo "     install -m $MODE -o $OWNER_U -g $OWNER_G -- ${SRCS[$i]} ${TARGETS[$i]}"
  done
  for u in "${UNITS[@]}"; do echo "  3. systemctl start $u; wait up to $WAIT s for 'active'"; done
  [ -z "$URL" ] || echo "  4. curl -sS -m 10 -o /dev/null -w %{http_code} ${URL%%\?*}   (2xx/3xx = pass)"
  echo "DRY RUN done."
  exit 0
fi

STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
PHASE=install
UNDO=0
WAS_ACTIVE=() ASIDES=() INSTALLED=()

rollback() {
  local pair a t u
  echo "ROLLING BACK: putting the original files back." >&2
  for t in "${INSTALLED[@]}"; do rm -f -- "$t"; done
  for pair in "${ASIDES[@]}"; do
    a="${pair%%|*}" t="${pair#*|}"
    mv -f -- "$a" "$t" || echo "WARN: could not move $a back to $t" >&2
  done
  for u in "${WAS_ACTIVE[@]}"; do
    systemctl start "$u" || echo "WARN: could not restart $u, start it by hand: systemctl start $u" >&2
  done
}
cleanup() {
  local rc=$?
  trap - EXIT
  if [ "$rc" -ne 0 ] && [ "$PHASE" = install ]; then rollback; fi
  exit "$rc"
}
trap cleanup EXIT

echo "==> stopping"
for u in "${UNITS[@]}"; do
  if systemctl is-active --quiet "$u"; then WAS_ACTIVE+=("$u"); fi
  echo "stopping $u"
  systemctl stop "$u"
done

echo "==> installing"
for i in "${!SRCS[@]}"; do
  src="${SRCS[$i]}" t="${TARGETS[$i]}"
  if [ -e "$t" ] || [ -L "$t" ]; then
    mv -- "$t" "$t.pre-restore-$STAMP"
    ASIDES+=("$t.pre-restore-$STAMP|$t")
    echo "moved aside: $(basename -- "$t") -> $(basename -- "$t").pre-restore-$STAMP"
  fi
  install -m "$MODE" -o "$OWNER_U" -g "$OWNER_G" -- "$src" "$t"
  INSTALLED+=("$t")
  want="$(sha256sum <"$src" | cut -d' ' -f1)"
  got="$(sha256sum <"$t" | cut -d' ' -f1)"
  [ "$want" = "$got" ] || die "installed copy of $(basename -- "$t") does not match its source"
  printf '  installed %10s bytes  %s  %s\n' "$(stat -c %s -- "$t")" "${got:0:16}" "$(basename -- "$t")"
done
PHASE=started

echo "==> starting"
for u in "${UNITS[@]}"; do
  systemctl start "$u" || { echo "FAILED to start $u." >&2; UNDO=1; }
done
deadline=$((SECONDS + WAIT))
for u in "${UNITS[@]}"; do
  until systemctl is-active --quiet "$u"; do
    if [ "$SECONDS" -ge "$deadline" ]; then UNDO=1; echo "FAILED: $u is not active after $WAIT s." >&2; break; fi
    sleep 1
  done
  if systemctl is-active --quiet "$u"; then echo "$u: active"; fi
done

code="" rc=0
if [ -n "$URL" ] && [ "$UNDO" -eq 0 ]; then
  while :; do
    code="$(curl -sS -m 10 -o /dev/null -w '%{http_code}' "$URL" 2>/dev/null)" && rc=0 || rc=$?
    if [[ "$code" =~ ^[23][0-9][0-9]$ ]]; then break; fi
    if [ "$SECONDS" -ge "$deadline" ]; then UNDO=1; echo "FAILED: ${URL%%\?*} answered '${code:-none}' (curl exit $rc) within $WAIT s." >&2; break; fi
    sleep 1
  done
  if [ "$UNDO" -eq 0 ]; then echo "url: ${URL%%\?*} -> HTTP $code"; fi
fi

if [ "$UNDO" -ne 0 ]; then
  echo "The restored files are STILL IN PLACE. To undo: systemctl stop <unit>; for each file, mv the .pre-restore-$STAMP copy over it; systemctl start <unit>." >&2
  exit 1
fi
echo "OK: restore-on-pi done (${#SRCS[@]} files, originals kept as *.pre-restore-$STAMP where they existed)."
