#!/usr/bin/env bash
# test-gc.sh — tests for the nixos-gc scripts. Deletes nothing real.
#   - bash -n on each script
#   - behaviour of `gc-preview.sh --delete-list` on fake profiles (rollback, old boot, few gens)
#   - gc.sh run with stub sudo/nix-env/nix-store first on PATH
#   - read-only gc-preview.sh against the real system profile
set -uo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PREVIEW="$SKILL_DIR/scripts/gc-preview.sh"
GC="$SKILL_DIR/scripts/gc.sh"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

pass=0
fail=0
check() { # check <name> <expected> <actual>
  if [ "$2" = "$3" ]; then
    pass=$((pass + 1)); echo "PASS  $1"
  else
    fail=$((fail + 1)); echo "FAIL  $1"; echo "      expected: '$2'"; echo "      actual:   '$3'"
  fi
}

# --- 1. syntax -------------------------------------------------------------
for s in "$PREVIEW" "$GC" "$0"; do
  if bash -n "$s"; then check "bash -n $(basename "$s")" ok ok; else check "bash -n $(basename "$s")" ok syntax-error; fi
done

# --- fixture helper --------------------------------------------------------
# make_fixture <dir> <nGens> <profileCurrent> <booted> <runningSystem>
# Creates <dir>/store/gen-N dirs, <dir>/profiles/system-N-link -> store/gen-N,
# profiles/system -> system-<profileCurrent>-link, and booted/running symlinks.
make_fixture() {
  local dir="$1" n="$2" cur="$3" booted="$4" running="$5" i
  mkdir -p "$dir/store" "$dir/profiles"
  for i in $(seq 1 "$n"); do
    mkdir -p "$dir/store/gen-$i"
    ln -s "../store/gen-$i" "$dir/profiles/system-$i-link"
  done
  ln -s "system-$cur-link" "$dir/profiles/system"
  ln -s "store/gen-$booted" "$dir/booted"
  ln -s "store/gen-$running" "$dir/running"
}

preview_list() { # preview_list <fixture-dir>
  NIXOS_GC_PROFILES="$1/profiles" NIXOS_GC_BOOTED="$1/booted" NIXOS_GC_CURRENT="$1/running" \
    "$PREVIEW" --delete-list | tr '\n' ' ' | sed 's/ $//'
}

# --- 2. rollback: profile current is an old generation -----------------------
# 10 gens, rolled back to 4, booted and running 10. Old code deleted 4 (nix-env refuses).
make_fixture "$WORK/rollback" 10 4 10 10
check "rollback: current gen 4 is kept, 3 newest kept" "1 2 3 5 6 7" "$(preview_list "$WORK/rollback")"

# --- 3. old boot: booted into an older generation -----------------------------
# 10 gens, profile and running 10, but booted 2. Gen 2 must survive.
make_fixture "$WORK/oldboot" 10 10 2 10
check "old boot: booted gen 2 is kept" "1 3 4 5 6 7" "$(preview_list "$WORK/oldboot")"

# --- 4. running differs from booted, and the running gen is old --------------
make_fixture "$WORK/running" 10 10 10 6
check "running: /run/current-system gen 6 is kept" "1 2 3 4 5 7" "$(preview_list "$WORK/running")"

# --- 5. three or fewer generations: nothing to delete ------------------------
make_fixture "$WORK/few" 3 3 3 3
check "3 gens: empty delete list" "" "$(preview_list "$WORK/few")"

# --- 6. gc.sh with stubs first on PATH ---------------------------------------
STUBS="$WORK/stubs"
LOG="$WORK/calls.log"
mkdir -p "$STUBS"
cat >"$STUBS/sudo" <<EOF
#!/usr/bin/env bash
echo "sudo \$*" >>"$LOG"
exec "\$@"
EOF
for tool in nix-env nix-store; do
  cat >"$STUBS/$tool" <<EOF
#!/usr/bin/env bash
echo "$tool \$*" >>"$LOG"
exit 0
EOF
done
chmod +x "$STUBS"/*

make_fixture "$WORK/gc" 10 4 10 10
: >"$LOG"
resolved="$(PATH="$STUBS:$PATH" command -v nix-env)"
check "stub nix-env resolves first on PATH" "$STUBS/nix-env" "$resolved"

PATH="$STUBS:$PATH" NIXOS_GC_PROFILES="$WORK/gc/profiles" NIXOS_GC_BOOTED="$WORK/gc/booted" \
  NIXOS_GC_CURRENT="$WORK/gc/running" "$GC" >"$WORK/gc.out" 2>&1
rc=$?
check "gc.sh exits 0 with stubs" "0" "$rc"
check "gc.sh deletes exactly 1 2 3 5 6 7 (current 4 spared)" \
  "nix-env -p /nix/var/nix/profiles/system --delete-generations 1 2 3 5 6 7" \
  "$(grep -- '^nix-env .*--delete-generations' "$LOG")"
check "gc.sh runs nix-store --gc" "1" "$(grep -c '^nix-store --gc$' "$LOG")"
check "gc.sh never deletes gen 4" "0" "$(grep -- '--delete-generations' "$LOG" | grep -cw '4')"

# --- 7. read-only preview against the real system profile --------------------
out="$("$PREVIEW" 2>&1)"; rc=$?
check "real profile: gc-preview.sh exits 0" "0" "$rc"
check "real profile: prints KEEP line" "1" "$(grep -c '==> Would KEEP:' <<<"$out")"
"$PREVIEW" --delete-list >/dev/null 2>&1; rc=$?
check "real profile: --delete-list exits 0" "0" "$rc"

echo
echo "Summary: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
