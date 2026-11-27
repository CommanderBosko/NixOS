#!/usr/bin/env bash
# gen-host-key.sh — pre-generate a Raspberry Pi's ssh ed25519 HOST key pair BEFORE its
# first boot, so sops-nix can decrypt the Pi's secrets on that very first boot.
#
# Usage: gen-host-key.sh <host> [--ip IP] [--check|--show]
#   <host>     host name or alias from .claude/hosts.json
#   --ip IP    Tailscale IP for a Pi not in hosts.json yet (never contacted)
#   (no mode)  generate into $PI_BACKUP_DIR/ssh-host/ (dir 0700, key 0600, pub 0644)
#              and print the public key, the age recipient and the .sops.yaml
#              snippet. REFUSES to overwrite an existing key (exit 1).
#   --check    report whether it would generate or refuse; generates nothing
#   --show     print the EXISTING public key + age recipient and whether that
#              recipient is already in .sops.yaml. Reads only the .pub file.
#   -h, --help this text
#
# <keydir> for flash-pi-media.sh / stage-remote.sh is  $PI_BACKUP_DIR/ssh-host
# ($PI_BACKUP_DIR defaults to ~/pi-backups/<host>/, outside the repo).
#
# Prints ONLY public material (public key, age recipient, snippets): never the
# private key. The private key goes onto the flashed media via flash-pi-media.sh and
# nowhere else (not the repo, not the Nix store, not a chat).
#
# Exit codes: 0 ok / would generate; 1 refused / would refuse / not found; 2 usage.
set -euo pipefail
umask 077 # the private key must never exist with loose permissions, even for a moment

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

need_keygen() {
  command -v ssh-keygen >/dev/null 2>&1 ||
    pi_die "ssh-keygen not found. Borrow it with: nix shell nixpkgs#openssh -c bash ${BASH_SOURCE[0]} $PI_NAME"
}

age_of_pub() { # <pub file>: print the age recipient (ssh-to-age on PATH, else via nix shell)
  if command -v ssh-to-age >/dev/null 2>&1; then
    ssh-to-age <"$1"
  else
    nix shell nixpkgs#ssh-to-age -c ssh-to-age <"$1"
  fi
}

sops_state() { # <age>: is this recipient already in .sops.yaml?
  local sops="$PI_REPO/.sops.yaml"
  if [ ! -f "$sops" ]; then
    echo "registered in .sops.yaml: unknown (no $sops)"
  elif grep -qF -- "$1" "$sops"; then
    echo "registered in .sops.yaml: YES"
  else
    echo "registered in .sops.yaml: NO (add it: see the snippet from a fresh generate, or references/sops-bootstrap.md)"
  fi
}

print_identity() { # <pub file> <age>
  echo "public key (safe to share):"
  echo "  $(cat "$1")"
  echo "age recipient (safe to share):"
  echo "  $2"
}

print_registration() { # <age>
  cat <<EOF

.sops.yaml: add an anchor under keys: and the alias to every rule that must decrypt for $PI_NAME:
  keys:
    - &$PI_NAME $1
  creation_rules:
    - path_regex: secrets/common\\.yaml\$
      key_groups:
        - age:
            # ... existing entries ...
            - *$PI_NAME
    # only if $PI_NAME gets its own secrets file (secrets/hosts/$PI_NAME.yaml):
    - path_regex: secrets/hosts/$PI_NAME\\.yaml\$
      key_groups:
        - age: [*admin, *$PI_NAME]

Then re-encrypt with 'sops updatekeys' and git add: the commands are in
  $REPO/.claude/skills/new-host/references/sops-registration.md  (steps 2-4)
and the pre-boot variant for a Pi is in
  $REPO/.claude/skills/pi-sd-flash/references/sops-bootstrap.md

The PRIVATE key stays in $KEYDIR and goes ONLY onto the media, via flash-pi-media.sh.
Never copy it into the repo, the Nix store, or a chat.
EOF
}

key_state() { # none | partial | full
  if [ -e "$KEY" ] && [ -e "$PUB" ]; then
    echo full
  elif [ -e "$KEY" ] || [ -e "$PUB" ]; then
    echo partial
  else
    echo none
  fi
}

cmd_check() {
  local state mode
  state=$(key_state)
  if command -v ssh-keygen >/dev/null 2>&1; then
    echo "ssh-keygen: found"
  else
    echo "ssh-keygen: MISSING (borrow it: nix shell nixpkgs#openssh -c ...)"
    if [ "$state" = none ]; then
      echo "would FAIL: cannot generate without ssh-keygen"
      exit 1
    fi
  fi
  if [ "$state" = none ]; then
    echo "would GENERATE: $KEY (+ .pub) for $PI_NAME; $KEYDIR created 0700, key 0600"
    exit 0
  fi
  echo "would REFUSE: a key already exists in $KEYDIR ($state); it is never overwritten."
  if [ -d "$KEYDIR" ]; then
    mode=$(stat -c %a "$KEYDIR")
    [ "$mode" = 700 ] || echo "NOTE: $KEYDIR is mode $mode (want 700): chmod 700 '$KEYDIR'"
  fi
  echo "Use --show for the public key, age recipient and .sops.yaml state."
  exit 1
}

cmd_show() {
  local age
  [ -f "$PUB" ] || pi_die "no public key at $PUB (generate one: gen-host-key.sh $PI_NAME)"
  age=$(age_of_pub "$PUB") || pi_die "could not derive the age recipient (ssh-to-age failed)"
  print_identity "$PUB" "$age"
  sops_state "$age"
  echo "private key location (not read): $KEY"
}

cmd_generate() {
  local age
  if [ "$(key_state)" != none ]; then
    echo "REFUSING: a host key already exists in $KEYDIR; it is never overwritten." >&2
    echo "          --show prints its public key + age recipient. To replace it deliberately," >&2
    echo "          move the old pair away yourself first (and re-register the new age key)." >&2
    exit 1
  fi
  need_keygen
  mkdir -p "$KEYDIR"
  chmod 700 "$PI_BACKUP_DIR" "$KEYDIR"
  ssh-keygen -q -t ed25519 -N "" -C "$PI_NAME-host-key" -f "$KEY"
  chmod 600 "$KEY"
  chmod 644 "$PUB"
  [ -s "$KEY" ] && [ -s "$PUB" ] || pi_die "ssh-keygen did not produce $KEY and $PUB"
  echo "generated: $KEY (0600) and $PUB (0644)"
  if age=$(age_of_pub "$PUB"); then
    print_identity "$PUB" "$age"
    print_registration "$age"
  else
    print_identity "$PUB" "(could not derive: run  nix shell nixpkgs#ssh-to-age -c ssh-to-age < $PUB)"
    echo "The key pair exists; derive the age recipient by hand and register it (see the references above)."
  fi
}

main() {
  local host="" ip="" mode=generate
  while [ $# -gt 0 ]; do
    case $1 in
      -h | --help)
        usage
        exit 0
        ;;
      --check | --show)
        [ "$mode" = generate ] || usage_err "--check and --show are mutually exclusive"
        mode=${1#--}
        ;;
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
  [[ $host =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || usage_err "host name '$host' has characters that do not belong in a path"

  pi_load "$host" "$ip"
  KEYDIR="$PI_BACKUP_DIR/ssh-host"
  KEY="$KEYDIR/ssh_host_ed25519_key"
  PUB="$KEY.pub"

  case $mode in
    check) cmd_check ;;
    show) cmd_show ;;
    generate) cmd_generate ;;
  esac
}

# Run only when executed; sourcing (the test does) just defines the functions.
if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
  main "$@"
fi
