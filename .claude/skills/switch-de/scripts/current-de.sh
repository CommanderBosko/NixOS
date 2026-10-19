#!/usr/bin/env bash
# current-de.sh <host> [target-de] — print the currently active
# desktop-environment module name (no .nix suffix) for a given host, parsed
# from that host's own block in flake.nix (never assumes; scopes strictly to
# that host so it can't accidentally match another host's DE line), plus the
# flake.nix line to edit and, when <target-de> is given, whether Step 4's
# SDDM/displayManager note applies.
#
# If the host's own block has no literal DE path but calls a shared module-list
# helper (e.g. gaming -> gamingModules), the helper's definition is searched
# instead and a "shared-helper:" line is printed — editing that line changes
# EVERY config built from the helper (gamingModules: the gaming host plus the
# lib.moduleSmoke.{amd,vpn} smoke-eval targets, which aren't hosts).
#
# Output on exit 0 (stdout, one "key: value" per line):
#   current:       <module name>
#   line:          flake.nix:<n>   (the DE import line to replace in Step 6)
#   shared-helper: <helper> — ...  (only when the line lives in a shared helper)
#   sddm-note:     yes — <reasons> | no | unknown — <why>
#
# sddm-note is "yes" when any of these hold (the Step 4 trigger):
#   - a non-comment `defaultSession` line exists under hosts/<host>/
#   - the current or target DE is a bare Wayland compositor (BARE_WAYLAND
#     below: no canonical session string)
#   - the current and target DEs default to different display-server families
#     (X11 <-> Wayland, per de_family below)
#   - either DE is missing from de_family (unknown family -> note, to be safe)
# Without <target-de> only the defaultSession check can run; a negative result
# then prints "unknown" rather than "no".
#
# Exit codes:
#   0  exactly one DE module found — details on stdout as above
#   1  no host block found, or no DE module found in that block
#   2  ambiguous — more than one DE module found in the host's block
#      (all candidates with their flake.nix lines printed to stderr; caller
#      should ask the user)
set -uo pipefail

HOST="${1:?usage: current-de.sh <host> [target-de]}"
TARGET="${2:-}"
SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO="$(cd "$SKILL_DIR/../../.." && pwd)"
FLAKE="$REPO/flake.nix"

# Wayland-only compositors with no canonical session string (Step 4 names
# niri and hyprland; omarchy is Hyprland under another module name, wayfire is
# the same kind of bare compositor).
BARE_WAYLAND="niri hyprland omarchy wayfire"

# Default display-server family of each module under
# modules/desktop-environments/. Add new DE modules here; an unlisted DE is
# "unknown" and always gets the note.
de_family() {
  case "$1" in
    niri|hyprland|omarchy|wayfire|cosmic|gnome|plasma) echo wayland ;;
    budgie|cinnamon|mate|pantheon|xfce) echo x11 ;;
    *) echo unknown ;;
  esac
}

# Host block, each line prefixed with its flake.nix line number ("NR:line").
BLOCK=$(awk -v host="$HOST" '
  BEGIN { depth = 0; capturing = 0 }
  capturing == 0 && $0 ~ ("^[[:space:]]*" host "[[:space:]]*=[[:space:]]*mkSystem[[:space:]]*\\{") {
    capturing = 1
  }
  capturing == 1 {
    print NR ":" $0
    n = gsub(/\{/, "{"); depth += n
    n = gsub(/\}/, "}"); depth -= n
    if (depth <= 0) exit
  }
' "$FLAKE")

if [ -z "$BLOCK" ]; then
  echo "current-de.sh: no host block found for '$HOST' in flake.nix" >&2
  exit 1
fi

de_names() {
  grep -oE 'desktop-environments/[A-Za-z0-9_-]+\.nix' | sed -E 's#desktop-environments/##; s#\.nix$##' | sort -u
}

SEARCHED="$BLOCK"
HELPER=""
MATCHES=$(echo "$BLOCK" | de_names)
COUNT=$(printf '%s\n' "$MATCHES" | grep -c .)

if [ "$COUNT" -eq 0 ]; then
  HELPER=$(echo "$BLOCK" | grep -oE '\b[A-Za-z]+Modules\b' | head -1)
  if [ -n "$HELPER" ]; then
    HBLOCK=$(awk -v h="$HELPER" '
      capturing == 0 && $0 ~ ("^[[:space:]]*" h "[[:space:]]*=") { capturing = 1; start = NR }
      capturing == 1 { print NR ":" $0; if ($0 ~ /^[[:space:]]*\](.*)?;[[:space:]]*$/) exit }
    ' "$FLAKE")
    SEARCHED="$HBLOCK"
    MATCHES=$(echo "$HBLOCK" | de_names)
    COUNT=$(printf '%s\n' "$MATCHES" | grep -c .)
  fi
fi

if [ "$COUNT" -eq 0 ]; then
  echo "current-de.sh: no desktop-environments module found in '$HOST' block (headless host?)" >&2
  exit 1
elif [ "$COUNT" -gt 1 ]; then
  echo "current-de.sh: ambiguous — multiple DE modules found for '$HOST':" >&2
  echo "$SEARCHED" | grep -E 'desktop-environments/[A-Za-z0-9_-]+\.nix' \
    | sed -E 's#^([0-9]+):[[:space:]]*#  flake.nix:\1: #' >&2
  exit 2
fi

CURRENT="$MATCHES"
LINE=$(echo "$SEARCHED" | grep "desktop-environments/$CURRENT\.nix" | head -1 | cut -d: -f1)

echo "current:       $CURRENT"
echo "line:          flake.nix:$LINE"
if [ -n "$HELPER" ]; then
  echo "shared-helper: $HELPER — '$HOST' takes its DE from this helper; editing flake.nix:$LINE changes every host/variant built from it."
fi

# --- Step 4 SDDM/displayManager note trigger ---
REASONS=()

HOSTDIR="$REPO/hosts/$HOST"
if [ -d "$HOSTDIR" ]; then
  while IFS= read -r hit; do
    [ -n "$hit" ] && REASONS+=("${hit#"$REPO"/} sets defaultSession")
  done < <(grep -rnE '^[^#]*defaultSession' "$HOSTDIR" --include='*.nix' 2>/dev/null | cut -d: -f1,2)
fi

if [ -n "$TARGET" ]; then
  for w in $BARE_WAYLAND; do
    [ "$CURRENT" = "$w" ] && REASONS+=("switching away from $CURRENT (bare Wayland compositor)")
    [ "$TARGET" = "$w" ] && REASONS+=("switching to $TARGET (bare Wayland compositor)")
  done
  CUR_FAM=$(de_family "$CURRENT")
  TGT_FAM=$(de_family "$TARGET")
  if [ "$CUR_FAM" = unknown ] || [ "$TGT_FAM" = unknown ]; then
    REASONS+=("display-server family unknown ($CURRENT=$CUR_FAM, $TARGET=$TGT_FAM)")
  elif [ "$CUR_FAM" != "$TGT_FAM" ]; then
    REASONS+=("display-server family changes ($CUR_FAM -> $TGT_FAM)")
  fi
fi

if [ "${#REASONS[@]}" -gt 0 ]; then
  joined=$(printf '%s; ' "${REASONS[@]}")
  echo "sddm-note:     yes — ${joined%; }"
elif [ -n "$TARGET" ]; then
  echo "sddm-note:     no"
else
  echo "sddm-note:     unknown — pass <target-de> to check the DE-switch conditions"
fi
