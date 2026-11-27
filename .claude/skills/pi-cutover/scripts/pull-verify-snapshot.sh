#!/usr/bin/env bash
#
# pull-verify-snapshot.sh - copy the frozen snapshot off the old Pi and PROVE it
# is intact. This is the mandatory gate of the cutover: the old Pi must not be
# powered down until this prints "GATE: PASS".
#
# It pulls <remote-dir> with scp -r (BatchMode, never prompts) into a fresh
# 0700 directory outside the repo, then checks:
#   - SHA256SUMS exists and lists exactly the files that arrived (none missing,
#     none extra)
#   - sha256sum -c SHA256SUMS passes for every file
#   - every *.json file parses ("jq empty")
# It prints the file count, total bytes and each file's sha256 (names and
# hashes only; file contents are never printed, and jq's own error text is
# suppressed because it can quote data).
#
# Usage:
#   pull-verify-snapshot.sh --host H [--ip IP] [--user USER] --remote-dir DIR [--dest DIR]
#   pull-verify-snapshot.sh --local-src DIR (--host H | --dest DIR)     # tests / re-verify
#
#   --host H          host name from .claude/hosts.json (or any name, with --ip)
#   --ip IP           tailscale IP; wins over hosts.json (a Pi not registered yet)
#   --user USER       login user on the Pi to pull from; defaults to the user in
#                     hosts.json. The OLD Pi OS node may only have a different
#                     user (famdash was 'natty'), so this is often needed.
#   --remote-dir DIR  snapshot directory on the Pi (path chars: letters, digits, . _ - / ~ +)
#   --dest DIR        where to put it (default: <backup dir>/snapshot-<UTC stamp>;
#                     <backup dir> is ~/pi-backups/<host>/, 0700); must not exist
#   --local-src DIR   verify a snapshot already on this machine instead of
#                     pulling (copies it to --dest; no ssh/scp)
#   -h, --help        this text
#
# Exit codes: 0 gate passed, 1 pull failed or verification failed, 2 usage error.

set -euo pipefail
umask 077

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
# shellcheck source=../../../lib/pi-host.sh
source "$REPO/.claude/lib/pi-host.sh"

PROG="pull-verify-snapshot.sh"
usage() {
  sed -n '/^# Usage:/,/^# Exit codes/p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}
usage_die() { echo "ERROR: $*" >&2; echo "Try: bash $PROG --help" >&2; exit 2; }

HOST="" IP="" RUSER="" REMOTE_DIR="" DEST="" LOCAL_SRC=""
while [ $# -gt 0 ]; do
  case "$1" in
    --host) [ $# -ge 2 ] || usage_die "--host needs a value"; HOST="$2"; shift 2 ;;
    --ip) [ $# -ge 2 ] || usage_die "--ip needs a value"; IP="$2"; shift 2 ;;
    --user) [ $# -ge 2 ] || usage_die "--user needs a value"; RUSER="$2"; shift 2 ;;
    --remote-dir) [ $# -ge 2 ] || usage_die "--remote-dir needs a value"; REMOTE_DIR="$2"; shift 2 ;;
    --dest) [ $# -ge 2 ] || usage_die "--dest needs a value"; DEST="$2"; shift 2 ;;
    --local-src) [ $# -ge 2 ] || usage_die "--local-src needs a value"; LOCAL_SRC="$2"; shift 2 ;;
    -h | --help) usage; exit 0 ;;
    *) usage_die "unknown argument: $1" ;;
  esac
done

if [ -n "$LOCAL_SRC" ]; then
  [ -z "$REMOTE_DIR" ] || usage_die "--local-src and --remote-dir are alternatives"
  [ -d "$LOCAL_SRC" ] || usage_die "--local-src is not a directory: $LOCAL_SRC"
  { [ -n "$DEST" ] || [ -n "$HOST" ]; } || usage_die "--local-src needs --dest or --host (for the default destination)"
else
  [ -n "$HOST" ] || usage_die "--host is required"
  [ -n "$REMOTE_DIR" ] || usage_die "--remote-dir is required"
  case "$REMOTE_DIR" in *[!A-Za-z0-9._/~+-]*) usage_die "odd characters in --remote-dir (allowed: letters, digits, . _ - / ~ +)" ;; esac
  REMOTE_DIR="${REMOTE_DIR%/}"
  [ -n "$REMOTE_DIR" ] || usage_die "refusing / as the remote dir"
fi
if [ -n "$RUSER" ]; then
  case "$RUSER" in *[!A-Za-z0-9._-]* | '') usage_die "odd characters in --user" ;; esac
fi

if [ -n "$HOST" ]; then
  pi_load "$HOST" "$IP"
  if [ -n "$RUSER" ]; then PI_USER="$RUSER"; PI_TARGET="$PI_USER@$PI_IP"; fi
fi

STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
[ -n "$DEST" ] || DEST="$PI_BACKUP_DIR/snapshot-$STAMP"
DEST="${DEST%/}"
if [ -e "$DEST" ]; then
  [ -d "$DEST" ] && [ -z "$(ls -A "$DEST")" ] || { echo "ERROR: --dest exists and is not empty: $DEST (a pull never overwrites another snapshot)" >&2; exit 1; }
  rmdir "$DEST"
fi
mkdir -p "$(dirname "$DEST")"
STAGE="$(mktemp -d "$(dirname "$DEST")/.pull.XXXXXX")"
trap 'rm -rf "$STAGE"' EXIT

if [ -n "$LOCAL_SRC" ]; then
  echo "pull: copying local snapshot $LOCAL_SRC"
  cp -a -- "$LOCAL_SRC" "$STAGE/"
  BASE="$(basename "$LOCAL_SRC")"
else
  echo "pull: scp -r $PI_TARGET:$REMOTE_DIR (BatchMode)"
  scp -p -r -q -o BatchMode=yes -o ConnectTimeout="${PI_SSH_TIMEOUT:-10}" "$PI_TARGET:$REMOTE_DIR" "$STAGE/" ||
    { echo "ERROR: scp failed; the Pi was not touched. Check the user (--user), the path, and that the file is readable by that user." >&2; exit 1; }
  BASE="$(basename "$REMOTE_DIR")"
fi
[ -d "$STAGE/$BASE" ] || { echo "ERROR: nothing arrived at $STAGE/$BASE" >&2; exit 1; }
mv "$STAGE/$BASE" "$DEST"
chmod -R go-rwx "$DEST"
echo "pulled to: $DEST (mode $(stat -c %a "$DEST"))"

fails=0
bad() { echo "  FAIL: $*"; fails=$((fails + 1)); }

cd "$DEST"
echo "verify:"
if [ ! -s SHA256SUMS ]; then
  bad "SHA256SUMS is missing or empty"
else
  listed="$(awk '{print substr($0, 67)}' SHA256SUMS | LC_ALL=C sort)"
  actual="$(find . -type f ! -path ./SHA256SUMS -printf '%P\n' | LC_ALL=C sort)"
  missing="$(comm -23 <(printf '%s\n' "$listed") <(printf '%s\n' "$actual"))"
  extra="$(comm -13 <(printf '%s\n' "$listed") <(printf '%s\n' "$actual"))"
  [ -z "$missing" ] || bad "listed in SHA256SUMS but missing: $(printf '%s' "$missing" | tr '\n' ' ')"
  [ -z "$extra" ] || bad "present but not in SHA256SUMS: $(printf '%s' "$extra" | tr '\n' ' ')"
  if sums_out="$(sha256sum -c SHA256SUMS 2>&1)"; then
    echo "  sha256sum -c: all files match"
  else
    bad "sha256sum -c: $(printf '%s\n' "$sums_out" | grep -v ': OK$' | grep -v '^$' | head -n 5 | tr '\n' ';')"
  fi
fi

n_files=0 n_json=0 total=0
while IFS= read -r -d '' f; do
  n_files=$((n_files + 1))
  total=$((total + $(stat -c %s -- "$f")))
  case "$f" in
    *.json | *.JSON)
      n_json=$((n_json + 1))
      jq empty -- "$f" >/dev/null 2>&1 || bad "not valid JSON: $f"
      ;;
  esac
done < <(find . -type f ! -path ./SHA256SUMS -printf '%P\0' | LC_ALL=C sort -z)
[ "$n_files" -gt 0 ] || bad "the snapshot holds no files"
[ "$n_json" -eq 0 ] || [ "$fails" -gt 0 ] || echo "  jq empty: $n_json JSON file(s) parse"
echo "files: $n_files, total bytes: $total"
while IFS= read -r -d '' f; do
  printf '  %10s bytes  %s  %s\n' "$(stat -c %s -- "$f")" "$(sha256sum <"$f" | cut -d' ' -f1)" "$f"
done < <(find . -type f ! -path ./SHA256SUMS -printf '%P\0' | LC_ALL=C sort -z)

if [ "$fails" -gt 0 ]; then
  echo "GATE: FAIL ($fails problem(s)). Do NOT power the Pi down. If the freeze script was run with a shutdown timer, cancel it on the Pi: sudo shutdown -c"
  exit 1
fi
echo "GATE: PASS. The snapshot at $DEST is intact; the old Pi can be powered down."
