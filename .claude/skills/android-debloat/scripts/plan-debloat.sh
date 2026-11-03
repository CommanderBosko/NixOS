#!/usr/bin/env bash
# plan-debloat.sh — turn a community debloat list into this device's disable plan. Offline and
# read-only: it only compares three text files, so it never touches a device.
#
# Usage: plan-debloat.sh INSTALLED CANDIDATES KEEP [NEVER]
#   INSTALLED   output of `adb shell pm list packages` (the device's real package list)
#   CANDIDATES  a community list (CleanYourTV, DumbTV, a Samsung list ...), one package per line
#   KEEP        packages the user said to keep (one per line; blank/comment lines ignored)
#   NEVER       never-disable list (default: ../assets/never-disable.txt next to this script)
#
# Prints one line per candidate, sorted, tagged with why:
#   DISABLE <pkg>   installed, not kept, not never-disable: safe to put in a batch
#   KEEP <pkg>      installed but the user keeps it
#   NEVER <pkg>     matches the never-disable list: refused, whatever the list says
#   ABSENT <pkg>    not installed on this device (nothing to do)
# Then a summary line "# disable=N keep=N never=N absent=N" on stderr.
# Exit: 0 ok; 2 usage error or an unreadable file.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$HERE/common.sh"

[ "$#" -ge 3 ] && [ "$#" -le 4 ] || { sed -n '2,19p' "${BASH_SOURCE[0]}" >&2; exit 2; }
INSTALLED="$1" CANDIDATES="$2" KEEP="$3" NEVER="${4:-$HERE/../assets/never-disable.txt}"
for f in "$INSTALLED" "$CANDIDATES" "$KEEP" "$NEVER"; do
  [ -r "$f" ] || { echo "plan-debloat.sh: cannot read $f" >&2; exit 2; }
done

declare -A inst keep
while IFS= read -r p; do inst["$p"]=1; done < <(norm_list "$INSTALLED")
while IFS= read -r p; do keep["$p"]=1; done < <(norm_list "$KEEP")

out=""
nd=0 nk=0 nn=0 na=0
while IFS= read -r p; do
  if [ -z "${inst[$p]+x}" ]; then out+="ABSENT $p"$'\n'; na=$((na + 1))
  elif is_never "$p" "$NEVER"; then out+="NEVER $p"$'\n'; nn=$((nn + 1))
  elif [ -n "${keep[$p]+x}" ]; then out+="KEEP $p"$'\n'; nk=$((nk + 1))
  else out+="DISABLE $p"$'\n'; nd=$((nd + 1))
  fi
done < <(norm_list "$CANDIDATES")

# Sorted by package so the output is stable and diffable; the tag stays the first word.
[ -z "$out" ] || printf '%s' "$out" | sort -k2
echo "# disable=$nd keep=$nk never=$nn absent=$na" >&2
