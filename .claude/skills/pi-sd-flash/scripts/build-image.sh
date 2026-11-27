#!/usr/bin/env bash
# build-image.sh — build the aarch64 NixOS sdImage for a Raspberry Pi host ON THIS
# MACHINE and print the path of the flashable .img.zst.
#
# Only a machine that can run aarch64 binaries can do this: gaming, through
# boot.binfmt.emulatedSystems = [ "aarch64-linux" ] (QEMU user emulation). Never
# build on the Pi itself (1-4 GB RAM).
#
# Usage: build-image.sh <host> [--dry-run] [--ip IP]
#   <host>      host name or alias from .claude/hosts.json
#   --dry-run   pass --dry-run to nix build: print what would be built/fetched,
#               build nothing, print no image path
#   --ip IP     Tailscale IP for a Pi that is not in hosts.json yet (the helper needs
#               one to resolve the host; it is never contacted)
#   -h, --help  this text
#
# Output: progress and warnings on stderr; on success one stdout line
#   IMAGE: <store path>/sd-image/<name>.img.zst
# Exit codes: 0 ok; 1 refused or build failed; 2 usage error.
#
# The build takes a while under emulation (sd-image assembly runs locally): run it
# in the background and wait for it rather than holding a foreground call.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
# shellcheck source=../../../lib/pi-host.sh
source "$REPO/.claude/lib/pi-host.sh"

usage() {
  awk '/^set -euo/ { exit } NR > 1 { sub(/^# ?/, ""); print }' "${BASH_SOURCE[0]}"
}

usage_err() {
  echo "ERROR: $*" >&2
  usage >&2
  exit 2
}

main() {
  local host="" ip="" dry=0 ref out o img="" found=""
  while [ $# -gt 0 ]; do
    case $1 in
      -h | --help)
        usage
        exit 0
        ;;
      --dry-run) dry=1 ;;
      --ip)
        [ $# -ge 2 ] || usage_err "--ip needs a value"
        ip=$2
        shift
        ;;
      -*) usage_err "unknown option $1" ;;
      *)
        [ -z "$host" ] || usage_err "only one host, got '$host' and '$1'"
        host=$1
        ;;
    esac
    shift
  done
  [ -n "$host" ] || usage_err "host name required"

  pi_load "$host" "$ip"
  pi_require_aarch64
  pi_builder_ok || pi_die "this machine cannot build aarch64-linux (no native aarch64 and no enabled qemu binfmt handler). Only gaming has boot.binfmt.emulatedSystems = [\"aarch64-linux\"]: run this skill there (ssh bosko@gaming), never build on the Pi"

  # nix only sees git-tracked files in a path flake: a new host dir, module or
  # secrets file that was never `git add`ed is silently missing from the build.
  local untracked
  untracked=$(git -C "$PI_REPO" status --porcelain -- "hosts/$PI_NAME" modules secrets 2>/dev/null | grep '^??' || true)
  if [ -n "$untracked" ]; then
    {
      echo "WARN: untracked files nix will NOT see (a path flake only includes git-tracked files):"
      echo "$untracked"
      echo "      git add them first (new files are invisible to the build until added)."
    } >&2
  fi

  ref=$(pi_flake_ref image)
  if [ "$dry" -eq 1 ]; then
    echo "dry run: nix build $ref --no-link --dry-run" >&2
    nix build "$ref" --no-link --dry-run
    exit 0
  fi

  echo "building $ref (emulated aarch64: expect a long build)" >&2
  out=$(nix build "$ref" --no-link --print-out-paths) || pi_die "nix build failed for $ref${untracked:+ (see the untracked-files warning above)}"

  for o in $out; do
    for img in "$o"/sd-image/*.img.zst "$o"/sd-image/*.img; do
      if [ -f "$img" ]; then
        found=$img
        break 2
      fi
    done
  done
  [ -n "$found" ] || pi_die "build succeeded but there is no .img.zst or .img under $out/sd-image/"
  echo "built: $(du -h "$found" | cut -f1) $found" >&2
  echo "IMAGE: $found"
}

# Run only when executed; sourcing (the test does) just defines the functions.
if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
  main "$@"
fi
