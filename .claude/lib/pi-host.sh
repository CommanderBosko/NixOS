#!/usr/bin/env bash
#
# pi-host.sh — Shared lookups for the Raspberry Pi skills (pi-sd-flash,
# pi-cutover, deploy-pi-host). SOURCE this file; do not execute it:
#
#   source "$REPO/.claude/lib/pi-host.sh"      # REPO = repo root
#
# It builds on hosts.sh (.claude/hosts.json is the single source of truth) and
# adds the few Pi-specific lookups every one of those scripts needs, so a host
# is named once (`famdash`, later `pi-hole`) and nothing is hardcoded per Pi.
# Callers keep their own `set -uo pipefail`; nothing here changes shell options.
# pi_die EXITS the calling script — only source this from scripts, not a shell.
#
# Environment (all optional):
#   PI_REPO          repo root (default: two levels above this file)
#   PI_BACKUP_ROOT   where per-host backups live (default: ~/pi-backups, 0700,
#                    deliberately OUTSIDE the repo — keys and state go there)
#   PI_SSH_TIMEOUT   ssh ConnectTimeout seconds (default 10)
#   HOSTS_JSON       alternate hosts.json (tests)
#
# Defines:
#   pi_die <msg...>          print "ERROR: msg" to stderr and exit 1
#   pi_load <name> [ip]      resolve a host (key or alias) from hosts.json; an
#                            explicit [ip] wins over .tailscaleIp and lets a Pi
#                            that is not registered yet (pi-hole, pre-migration)
#                            work. Sets and exports:
#                              PI_NAME    canonical host name
#                              PI_IP      tailscale IP (stable; LAN IPs drift)
#                              PI_ARCH    .arch from hosts.json (default aarch64-linux)
#                              PI_USER    login user from .ssh (default bosko)
#                              PI_TARGET  PI_USER@PI_IP
#                              PI_BACKUP_DIR  $PI_BACKUP_ROOT/$PI_NAME
#   pi_require_aarch64       exit unless PI_ARCH is aarch64-linux
#   pi_builder_ok            0 if THIS machine can build aarch64 (native, or the
#                            qemu binfmt handler is registered and enabled)
#   pi_ssh <cmd...>          ssh -o BatchMode=yes to PI_TARGET (never prompts)
#   pi_attr <image|toplevel> flake attr for the host's sdImage / toplevel
#   pi_flake_ref <image|toplevel>   "$PI_REPO#<attr>" ready for nix build/eval

_PI_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
# shellcheck source=hosts.sh
source "$_PI_LIB_DIR/hosts.sh"

PI_REPO="${PI_REPO:-$(cd "$_PI_LIB_DIR/../.." && pwd)}"
PI_BACKUP_ROOT="${PI_BACKUP_ROOT:-$HOME/pi-backups}"

pi_die() {
  echo "ERROR: $*" >&2
  exit 1
}

pi_load() {
  local name="${1:-}" ip_override="${2:-}" canon ssh_target
  [ -n "$name" ] || pi_die "pi_load: host name required"
  canon="$(hosts_canonical "$name")"
  PI_NAME="${canon:-$name}"
  PI_IP=""
  PI_ARCH="aarch64-linux"
  PI_USER="bosko"
  if [ -n "$canon" ]; then
    # shellcheck disable=SC2016  # $n is a jq variable, not shell
    PI_IP="$(hosts_jq -r --arg n "$canon" '.hosts[$n].tailscaleIp // empty')"
    # shellcheck disable=SC2016  # $n is a jq variable, not shell
    PI_ARCH="$(hosts_jq -r --arg n "$canon" '.hosts[$n].arch // "aarch64-linux"')"
    ssh_target="$(hosts_ssh "$canon")"
    case "$ssh_target" in *@*) PI_USER="${ssh_target%@*}" ;; esac
  fi
  [ -n "$ip_override" ] && PI_IP="$ip_override"
  [ -n "$PI_IP" ] || pi_die "no tailscaleIp for '$name' in hosts.json and no IP given"
  PI_TARGET="$PI_USER@$PI_IP"
  PI_BACKUP_DIR="$PI_BACKUP_ROOT/$PI_NAME"
  export PI_NAME PI_IP PI_ARCH PI_USER PI_TARGET PI_BACKUP_DIR
}

pi_require_aarch64() {
  [ "${PI_ARCH:-}" = "aarch64-linux" ] ||
    pi_die "$PI_NAME is ${PI_ARCH:-unknown}, not aarch64-linux — these skills are for Raspberry Pi hosts"
}

pi_builder_ok() {
  [ "$(uname -m)" = "aarch64" ] && return 0
  local h=/proc/sys/fs/binfmt_misc/aarch64-linux
  [ -r "$h" ] && head -n1 "$h" | grep -qx enabled
}

pi_ssh() {
  ssh -o BatchMode=yes -o ConnectTimeout="${PI_SSH_TIMEOUT:-10}" "$PI_TARGET" "$@"
}

pi_attr() {
  case "${1:-}" in
    image) echo "nixosConfigurations.$PI_NAME.config.system.build.sdImage" ;;
    toplevel) echo "nixosConfigurations.$PI_NAME.config.system.build.toplevel" ;;
    *) pi_die "pi_attr: want 'image' or 'toplevel', got '${1:-}'" ;;
  esac
}

pi_flake_ref() {
  echo "$PI_REPO#$(pi_attr "$1")"
}
