#!/usr/bin/env bash
# diff-generations.sh — store-closure diff between the PREVIOUS and CURRENT NixOS
# generation. Read-only. Resolves the previous generation robustly: the highest
# generation number strictly below the current one that still exists on disk
# (the old "system-1-link" shortcut was wrong — that's literally generation 1).
#
# After the diff, if any changed package name contains linux-, kernel, or
# initrd, it prints a final "==> Kernel or initrd changed (...) — a reboot is
# required ..." line for SKILL.md Step 3 to relay.
#
# Exit: 0 diff printed | 1 current generation unresolvable | 2 no previous
# generation | otherwise nix store diff-closures' own exit code.
set -uo pipefail

PROFILES="/nix/var/nix/profiles"

cur_n=$(readlink "$PROFILES/system" 2>/dev/null | sed -n 's/^system-\([0-9]*\)-link$/\1/p')
if [ -z "${cur_n:-}" ]; then
  echo "ERROR: could not resolve the current generation number from $PROFILES/system." >&2
  exit 1
fi

# Largest generation number strictly less than the current one, that still exists.
prev_n=""
while read -r g; do
  [ "$g" -lt "$cur_n" ] && prev_n=$g
done < <(ls -1 "$PROFILES" 2>/dev/null | sed -n 's/^system-\([0-9]*\)-link$/\1/p' | sort -n)

if [ -z "$prev_n" ]; then
  echo "No previous generation to compare against (current is generation $cur_n)." >&2
  exit 2
fi

# Diff profile links, not /run/current-system: after `nh os boot` the newest
# generation is staged but not running, and N-1 -> N must mean exactly that.
prev="$PROFILES/system-${prev_n}-link"
cur="$PROFILES/system-${cur_n}-link"
echo "==> Diffing generation ${prev_n} -> ${cur_n}"
echo "    $prev"
echo "    $cur"
echo
diff_out="$(nix store diff-closures "$prev" "$cur")"
rc=$?
[ -n "$diff_out" ] && printf '%s\n' "$diff_out"
[ "$rc" -ne 0 ] && exit "$rc"

# Each diff line is "<name>: <versions>, <size>"; strip colour codes, keep the
# names, and flag the ones that need a reboot to take effect.
reboot_names="$(printf '%s\n' "$diff_out" \
  | sed 's/\x1b\[[0-9;]*m//g' \
  | sed -n 's/^\([^:]*\): .*/\1/p' \
  | grep -E 'linux-|kernel|initrd' \
  | sort -u | paste -sd, - | sed 's/,/, /g')"
if [ -n "$reboot_names" ]; then
  echo
  echo "==> Kernel or initrd changed ($reboot_names) — a reboot is required to activate these changes."
fi
exit 0
