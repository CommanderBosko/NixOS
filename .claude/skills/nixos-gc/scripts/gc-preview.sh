#!/usr/bin/env bash
# gc-preview.sh — READ-ONLY helper for the nixos-gc skill. Deletes nothing.
#
# Usage:
#   gc-preview.sh                 show all generations, what would be kept and deleted
#   gc-preview.sh --delete-list   print only the generation numbers to delete, one per line
#
# gc.sh takes its list from --delete-list, so preview and delete cannot drift apart.
# A generation is KEPT if it is any of:
#   - one of the 3 newest by number
#   - the profile's current generation (what `system` points at; nix-env refuses to delete it)
#   - a generation whose target is /run/booted-system or /run/current-system
# Unprivileged — no sudo.
#
# Env overrides (used by tests/test-gc.sh): NIXOS_GC_PROFILES, NIXOS_GC_BOOTED, NIXOS_GC_CURRENT.
set -uo pipefail

PROFILES="${NIXOS_GC_PROFILES:-/nix/var/nix/profiles}"
BOOTED="${NIXOS_GC_BOOTED:-/run/booted-system}"
RUNNING="${NIXOS_GC_CURRENT:-/run/current-system}"

MODE=preview
case "${1:-}" in
  "") ;;
  --delete-list) MODE=delete-list ;;
  *) echo "usage: $0 [--delete-list]" >&2; exit 2 ;;
esac

gen_of_link() { sed -n 's/^system-\([0-9]*\)-link$/\1/p' <<<"$1"; }
target_of() { readlink -f "$1" 2>/dev/null; }

mapfile -t GENS < <(ls -1 "$PROFILES" 2>/dev/null | sed -n 's/^system-\([0-9]*\)-link$/\1/p' | sort -n)
if [ "${#GENS[@]}" -eq 0 ]; then
  echo "ERROR: could not find any system-*-link generations under $PROFILES" >&2
  exit 1
fi

CURRENT_GEN="$(gen_of_link "$(readlink "$PROFILES/system" 2>/dev/null)")"
if [ -z "$CURRENT_GEN" ]; then
  echo "ERROR: cannot determine the current generation from $PROFILES/system; refusing to guess" >&2
  exit 1
fi
BOOTED_T="$(target_of "$BOOTED")"
RUNNING_T="$(target_of "$RUNNING")"

TOTAL="${#GENS[@]}"
DELETE=()
for i in "${!GENS[@]}"; do
  g="${GENS[$i]}"
  [ "$i" -ge $((TOTAL - 3)) ] && continue
  [ "$g" = "$CURRENT_GEN" ] && continue
  t="$(target_of "$PROFILES/system-${g}-link")"
  if [ -n "$t" ] && { [ "$t" = "$BOOTED_T" ] || [ "$t" = "$RUNNING_T" ]; }; then
    continue
  fi
  DELETE+=("$g")
done

if [ "$MODE" = delete-list ]; then
  if [ "${#DELETE[@]}" -gt 0 ]; then
    printf '%s\n' "${DELETE[@]}"
  fi
  exit 0
fi

is_deleted() { case " ${DELETE[*]:-} " in *" $1 "*) return 0 ;; *) return 1 ;; esac; }

echo "== all generations (oldest first) =="
KEEP=()
for g in "${GENS[@]}"; do
  ts="$(stat -c '%y' "$PROFILES/system-${g}-link" 2>/dev/null | cut -d. -f1)"
  t="$(target_of "$PROFILES/system-${g}-link")"
  note=""
  [ "$g" = "$CURRENT_GEN" ] && note="$note current"
  [ -n "$t" ] && [ "$t" = "$BOOTED_T" ] && note="$note booted"
  [ -n "$t" ] && [ "$t" = "$RUNNING_T" ] && note="$note running"
  printf '  %-5s %s%s\n' "$g" "$ts" "${note:+  [$(echo "$note" | sed 's/^ //; s/ /, /g')]}"
  is_deleted "$g" || KEEP+=("$g")
done

echo
echo "==> Would KEEP:   ${KEEP[*]}"
if [ "${#DELETE[@]}" -gt 0 ]; then
  echo "==> Would DELETE: ${DELETE[*]}"
else
  echo "==> Would DELETE: (none) — nothing would be deleted."
fi
