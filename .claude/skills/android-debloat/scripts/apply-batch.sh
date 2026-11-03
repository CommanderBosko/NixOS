#!/usr/bin/env bash
# apply-batch.sh — disable one small batch of packages on an Android device over adb, or check
# afterwards that the batch survived a reboot. DRY-RUN BY DEFAULT: nothing touches the device
# unless --apply is given. Only ever runs `pm disable-user --user 0` (undo: `pm enable`); it never
# uninstalls, clears data, resets or changes settings.
#
# Usage:
#   apply-batch.sh [--apply] [--log FILE] TARGET PLAN
#   apply-batch.sh --verify TARGET PLAN
#     TARGET  an adb serial, or <tailscale-ip>:<port> (the user's rule: tailnet addresses, not LAN)
#     PLAN    one package per line (bare names, or plan-debloat.sh output: only DISABLE lines count)
#   --apply   really run the disables, stopping at the first failure; ends with `sync`
#   --verify  list which PLAN packages are NOT in `pm list packages -d` (reverted by a reboot too early)
# Env: ADB (default `adb`; run the script inside `nix shell nixpkgs#android-tools -c ...` when adb
#      is not installed), NEVER_FILE (default ../assets/never-disable.txt), MAX_BATCH (default 10).
# Exit: 0 ok; 1 a disable failed, a package was refused, or --verify found reverted packages;
#       2 usage error (including a batch over MAX_BATCH).
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$HERE/common.sh"

ADB="${ADB:-adb}"
NEVER_FILE="${NEVER_FILE:-$HERE/../assets/never-disable.txt}"
MAX_BATCH="${MAX_BATCH:-10}"
MODE=dry LOG=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --apply) MODE=apply; shift ;;
    --verify) MODE=verify; shift ;;
    --log) LOG="${2:?--log needs a file}"; shift 2 ;;
    --) shift; break ;;
    -*) echo "apply-batch.sh: unknown flag $1" >&2; exit 2 ;;
    *) break ;;
  esac
done
[ "$#" -eq 2 ] || { sed -n '2,19p' "${BASH_SOURCE[0]}" >&2; exit 2; }
TARGET="$1" PLAN="$2"
[ -r "$PLAN" ] || { echo "apply-batch.sh: cannot read $PLAN" >&2; exit 2; }
[ -r "$NEVER_FILE" ] || { echo "apply-batch.sh: cannot read $NEVER_FILE" >&2; exit 2; }

# A plan file may be plan-debloat.sh output: keep only DISABLE lines when any tag is present.
if grep -qE '^(DISABLE|KEEP|NEVER|ABSENT) ' "$PLAN"; then
  mapfile -t PKGS < <(grep -E '^DISABLE ' "$PLAN" | sed 's/^DISABLE //' | tr -d '\r' | sort -u)
else
  mapfile -t PKGS < <(norm_list "$PLAN")
fi
[ "${#PKGS[@]}" -gt 0 ] || { echo "apply-batch.sh: no packages in $PLAN" >&2; exit 2; }

if [ "$MODE" = verify ]; then
  disabled="$("$ADB" -s "$TARGET" shell pm list packages -d | tr -d '\r' | sed 's/^package://')"
  bad=0
  for p in "${PKGS[@]}"; do
    if grep -qxF "$p" <<<"$disabled"; then echo "STILL-DISABLED $p"
    else echo "REVERTED $p"; bad=$((bad + 1)); fi
  done
  [ "$bad" -eq 0 ] || { echo "apply-batch.sh: $bad package(s) reverted - re-apply, and wait ~20 s after the last disable before rebooting" >&2; exit 1; }
  exit 0
fi

[ "${#PKGS[@]}" -le "$MAX_BATCH" ] || { echo "apply-batch.sh: ${#PKGS[@]} packages is over MAX_BATCH=$MAX_BATCH; split the plan into smaller batches" >&2; exit 2; }
for p in "${PKGS[@]}"; do
  if is_never "$p" "$NEVER_FILE"; then
    echo "apply-batch.sh: REFUSED $p matches the never-disable list ($NEVER_FILE)" >&2
    exit 1
  fi
done

log() { [ -z "$LOG" ] || printf '%s\n' "$*" >>"$LOG"; }
for p in "${PKGS[@]}"; do
  cmd=("$ADB" -s "$TARGET" shell pm disable-user --user 0 "$p")
  if [ "$MODE" = dry ]; then
    echo "DRY-RUN ${cmd[*]}    # undo: $ADB -s $TARGET shell pm enable $p"
    continue
  fi
  res="$("${cmd[@]}" 2>&1 | tr -d '\r')" || true
  if grep -q 'new state: disabled-user' <<<"$res"; then
    echo "OK $p"; log "OK $p"
  else
    echo "FAIL $p: $res" >&2; log "FAIL $p: $res"
    exit 1
  fi
done
if [ "$MODE" = apply ]; then
  "$ADB" -s "$TARGET" shell sync
  echo "applied ${#PKGS[@]} package(s). Next: wait ~20 s, reboot, then run: apply-batch.sh --verify $TARGET $PLAN"
fi
