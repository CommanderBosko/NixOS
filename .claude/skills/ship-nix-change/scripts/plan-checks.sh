#!/usr/bin/env bash
#
# plan-checks.sh — Print the verification checks a NixOS config change needs
# before ship-nix-change commits it (the skill's Steps 1 and 3, as a script).
#
# Changed files = the union of `git diff --name-only` (unstaged) and
# `git diff --name-only --cached` (staged), or `git diff --name-only RANGE`
# when a range is given. Each file is classified by the shared
# .claude/lib/classify-shared-file.sh (reads flake.nix live — never a
# hardcoded copy of the module lists). Then:
#   - nixos-dry-run          always (Step 2's baseline)
#   - shared-module-check    if any file is SHARED
#   - de-smoke-check <name>  else, for each changed modules/desktop-environments/
#                            file that is LOCAL and that flake.nix never
#                            references (no host imports it); skipped if the
#                            file was deleted
#   - nothing extra          otherwise (host-local files only)
#
# Usage:
#   plan-checks.sh [RANGE]
#
#   RANGE   optional git range (e.g. HEAD~3..HEAD) to plan for already-committed
#           changes instead of the working tree + index
#
# Output: a "changed files" block (one "<SHARED|LOCAL>  <file>  (note)" line per
# file) and a "required checks" block (one check per line, in run order).
# Exit: 0 plan printed | 1 no changed files (nothing to ship) | 2 usage/git error.
#
# Read-only: runs git diff and the classifier; never evaluates or builds.

set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
CLASSIFY="$REPO/.claude/lib/classify-shared-file.sh"
FLAKE="$REPO/flake.nix"

usage() {
  echo "usage: plan-checks.sh [RANGE]" >&2
  exit 2
}

case "${1:-}" in
  -h|--help)
    awk 'NR > 1 && /^#/ { sub(/^# ?/, ""); print; next } NR > 1 { exit }' "${BASH_SOURCE[0]}"
    exit 0
    ;;
  -*) usage ;;
esac
[ $# -le 1 ] || usage

if [ $# -eq 1 ]; then
  files="$(git -C "$REPO" diff --name-only "$1")" \
    || { echo "plan-checks.sh: git diff failed for range '$1'" >&2; exit 2; }
  source_desc="range $1"
else
  unstaged="$(git -C "$REPO" diff --name-only)" || exit 2
  staged="$(git -C "$REPO" diff --name-only --cached)" || exit 2
  files="$(printf '%s\n%s\n' "$unstaged" "$staged")"
  source_desc="working tree + staged"
fi

mapfile -t FILES < <(printf '%s\n' "$files" | sed '/^$/d' | sort -u)

if [ "${#FILES[@]}" -eq 0 ]; then
  echo "No changed files ($source_desc) — nothing to ship."
  exit 1
fi

shared=()
de=()

echo "== changed files ($source_desc) =="
for f in "${FILES[@]}"; do
  class="$(bash "$CLASSIFY" "$f" "$FLAKE")" \
    || { echo "plan-checks.sh: classify-shared-file.sh failed on $f" >&2; exit 2; }
  if [[ "$class" == SHARED* ]]; then
    shared+=("$f")
    printf 'SHARED  %s  (%s)\n' "$f" "${class#SHARED: }"
    continue
  fi
  note=""
  if [[ "$f" == modules/desktop-environments/*.nix ]] && ! grep -qF "$f" "$FLAKE"; then
    if [ -e "$REPO/$f" ]; then
      de+=("$(basename "$f" .nix)")
      note="  (DE module no host imports)"
    else
      note="  (deleted DE module, nothing to smoke-check)"
    fi
  fi
  printf 'LOCAL   %s%s\n' "$f" "$note"
done

echo "== required checks (in order) =="
echo "nixos-dry-run"
if [ "${#shared[@]}" -gt 0 ]; then
  echo "shared-module-check"
elif [ "${#de[@]}" -gt 0 ]; then
  for m in "${de[@]}"; do
    echo "de-smoke-check $m"
  done
fi
