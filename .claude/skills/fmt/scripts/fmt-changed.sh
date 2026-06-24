#!/usr/bin/env bash
# fmt-changed.sh — format changed + untracked .nix files with alejandra
# (fallback nixpkgs-fmt). Prints which files ended up reformatted. Exits 0 on
# a clean no-op; exits 1 only if no formatter is available.
set -uo pipefail
REPO="/home/bosko/NixOS"

mapfile -t files < <(
  {
    git -C "$REPO" diff --name-only HEAD -- '*.nix'
    git -C "$REPO" ls-files --others --exclude-standard -- '*.nix'
  } | sort -u
)

if [ ${#files[@]} -eq 0 ]; then
  echo "No changed .nix files to format."
  exit 0
fi

if command -v alejandra >/dev/null 2>&1; then
  fmt=alejandra
elif command -v nixpkgs-fmt >/dev/null 2>&1; then
  fmt=nixpkgs-fmt
else
  echo "ERROR: neither alejandra nor nixpkgs-fmt on PATH." >&2
  echo "Run via: nix run nixpkgs#alejandra -- <files>" >&2
  exit 1
fi

abs=()
for f in "${files[@]}"; do abs+=("$REPO/$f"); done

echo "==> Formatting ${#abs[@]} changed .nix file(s) with $fmt"
printf '    %s\n' "${files[@]}"
echo
"$fmt" "${abs[@]}"

echo
reformatted=$(git -C "$REPO" diff --name-only -- '*.nix')
if [ -z "$reformatted" ]; then
  echo "==> All changed .nix files were already correctly formatted."
else
  echo "==> Reformatted (now differ from HEAD):"
  echo "$reformatted" | sed 's/^/    /'
fi
