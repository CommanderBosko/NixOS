#!/usr/bin/env bash
#
# verify-boot.sh - verify the NEW NixOS boot of a Pi after the media swap.
#
# Read-only: it never changes the Pi. The one thing it can change on THIS
# machine is ~/.ssh/known_hosts, and only with --fix-known-hosts. Output is one
# line per check:
#     PASS|WARN|FAIL|SKIP <check>: <detail>
# and a final   RESULT: PASS|FAIL (n fail, n warn)   (FAIL if any check failed).
#
# Checks, in order:
#   ping         waits for the tailscale IP to answer (polls every 5 s up to --wait)
#   hostkey      ssh-keyscan -t ed25519 against the fingerprint of --expect-pubkey
#                (a PUBLIC key file: the one pre-generated for this Pi before
#                flashing). FAIL = this is not the Pi you flashed. SKIP without it.
#   known_hosts  an entry for the IP/name that differs from the scanned key is a
#                WARN with the 'ssh-keygen -R' fix; --fix-known-hosts applies it
#   ssh          BatchMode login works. When hostkey PASSED the session is pinned
#                to the verified key (a temp known_hosts), so a stale
#                ~/.ssh/known_hosts cannot block the check and nothing is written.
#                When hostkey FAILED, ssh and the probes are SKIPped: whatever
#                answers is not the Pi you flashed, so it is not worth probing
#   then ONE batched read-only ssh session probes:
#   failed-units systemctl --failed must be empty        system  running generation
#   root-fs      root partition >= 90% of its disk (else expand-root-partition
#                did not run; the detail has the manual fix)
#   tailscale    tailscaled active and tailscale0 has an IPv4 address
#   link:DEV     per --link, nmcli shows the device connected (SKIP if no nmcli)
#   journald     /var/log/journal exists (persistent logs)   [WARN only]
#   secret:NAME  per --secret, /run/secrets/NAME exists (existence only; never read)
#   unit:U       per --unit, systemctl is-active
#   url:URL      per --url, curl runs ON the Pi; 2xx/3xx passes
# A failing probe never aborts the others.
#
# Usage:
#   verify-boot.sh --host H [--ip IP] [--expect-pubkey FILE] [--wait SECONDS | --no-wait]
#        [--unit U]... [--url URL]... [--secret NAME]... [--link DEV]... [--fix-known-hosts]
#
#   --host H             host name from .claude/hosts.json (or any name, with --ip)
#   --ip IP              tailscale IP; wins over hosts.json
#   --expect-pubkey FILE public ssh-ed25519 key file expected on the Pi (a private
#                        key is refused)
#   --wait SECONDS       how long to wait for the Pi to come up (default 300)
#   --no-wait            one attempt per check, no waiting
#   --fix-known-hosts    ssh-keygen -R for the IP and the name when a stale entry
#                        exists and the hostkey check did not FAIL
#   -h, --help           this text
#
# Environment: PI_POLL_INTERVAL (seconds between polls, default 5), KNOWN_HOSTS
# (known_hosts file to inspect, default ~/.ssh/known_hosts), PI_SSH_TIMEOUT.
#
# Exit codes: 0 no FAIL (WARNs allowed), 1 at least one FAIL, 2 usage error.

set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
# shellcheck source=../../../lib/pi-host.sh
source "$REPO/.claude/lib/pi-host.sh"

PROG="verify-boot.sh"
usage() {
  sed -n '/^# Usage:/,/^# Exit codes/p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}
usage_die() { echo "ERROR: $*" >&2; echo "Try: bash $PROG --help" >&2; exit 2; }

HOST="" IP="" PUBKEY="" WAIT=300 FIX_KH=0
UNITS=() URLS=() SECRETS=() LINKS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --host) [ $# -ge 2 ] || usage_die "--host needs a value"; HOST="$2"; shift 2 ;;
    --ip) [ $# -ge 2 ] || usage_die "--ip needs a value"; IP="$2"; shift 2 ;;
    --expect-pubkey) [ $# -ge 2 ] || usage_die "--expect-pubkey needs a value"; PUBKEY="$2"; shift 2 ;;
    --wait) [ $# -ge 2 ] || usage_die "--wait needs a value"; WAIT="$2"; shift 2 ;;
    --no-wait) WAIT=0; shift ;;
    --unit) [ $# -ge 2 ] || usage_die "--unit needs a value"; UNITS+=("$2"); shift 2 ;;
    --url) [ $# -ge 2 ] || usage_die "--url needs a value"; URLS+=("$2"); shift 2 ;;
    --secret) [ $# -ge 2 ] || usage_die "--secret needs a value"; SECRETS+=("$2"); shift 2 ;;
    --link) [ $# -ge 2 ] || usage_die "--link needs a value"; LINKS+=("$2"); shift 2 ;;
    --fix-known-hosts) FIX_KH=1; shift ;;
    -h | --help) usage; exit 0 ;;
    *) usage_die "unknown argument: $1" ;;
  esac
done

[ -n "$HOST" ] || usage_die "--host is required"
case "$WAIT" in '' | *[!0-9]*) usage_die "--wait must be a whole number of seconds" ;; esac
for u in "${UNITS[@]}"; do
  case "$u" in '' | *[!A-Za-z0-9:_.@-]*) usage_die "odd characters in --unit: $u" ;; esac
done
for s in "${SECRETS[@]}"; do
  case "$s" in '' | *[!A-Za-z0-9._/-]* | *..*) usage_die "odd characters in --secret: $s" ;; esac
done
for d in "${LINKS[@]}"; do
  case "$d" in '' | *[!A-Za-z0-9._-]*) usage_die "odd characters in --link: $d" ;; esac
done
for u in "${URLS[@]}"; do
  case "$u" in http://* | https://*) ;; *) usage_die "--url must start with http:// or https://: $u" ;; esac
  case "$u" in *[[:space:]]*) usage_die "--url must not contain whitespace" ;; esac
done
if [ -n "$PUBKEY" ]; then
  [ -r "$PUBKEY" ] || usage_die "--expect-pubkey file is not readable: $PUBKEY"
  if grep -q 'PRIVATE KEY' "$PUBKEY" 2>/dev/null; then
    usage_die "--expect-pubkey must be a PUBLIC key file (that one holds a private key; refusing to use it)"
  fi
fi

pi_load "$HOST" "$IP"

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
KH="${KNOWN_HOSTS:-$HOME/.ssh/known_hosts}"
POLL="${PI_POLL_INTERVAL:-5}"
NFAIL=0 NWARN=0
emit() { # status check detail
  printf '%s %s: %s\n' "$1" "$2" "$3"
  case "$1" in FAIL) NFAIL=$((NFAIL + 1)) ;; WARN) NWARN=$((NWARN + 1)) ;; esac
}
START=$SECONDS
DEADLINE=$((START + WAIT))
poll() { # poll CMD...: retry until it succeeds or the --wait window closes
  while :; do
    "$@" && return 0
    [ "$SECONDS" -lt "$DEADLINE" ] || return 1
    sleep "$POLL"
  done
}
fp_of() { ssh-keygen -lf "$1" 2>/dev/null | awk 'NR==1{print $2}'; }

# --- 1. ping ------------------------------------------------------------------
do_ping() { ping -c 1 -W 2 "$PI_IP" >/dev/null 2>&1; }
if poll do_ping; then
  emit PASS ping "$PI_IP answered after $((SECONDS - START)) s"
else
  emit FAIL ping "no answer from $PI_IP within ${WAIT} s (powered on? the tailnet comes up about 30 s after power-on; a Pi on the old media may still hold this IP)"
fi

# --- 2. host key ----------------------------------------------------------------
SCAN_LINE="" s_type="" s_blob="" scan_fp="" HOSTKEY=skip
do_scan() {
  SCAN_LINE="$(ssh-keyscan -t ed25519 -T 5 "$PI_IP" 2>/dev/null | grep -v '^#' | head -n1)"
  [ -n "$SCAN_LINE" ]
}
if poll do_scan; then
  read -r _ s_type s_blob _ <<<"$SCAN_LINE"
  if [ "$s_type" = ssh-ed25519 ] && [ -n "$s_blob" ]; then
    printf '%s %s\n' "$s_type" "$s_blob" >"$TMP/scanned.pub"
    scan_fp="$(fp_of "$TMP/scanned.pub")"
  else
    s_blob=""
  fi
fi
if [ -n "$PUBKEY" ]; then
  want_fp="$(fp_of "$PUBKEY")"
  if [ -z "$want_fp" ]; then
    emit FAIL hostkey "no fingerprint could be read from $(basename "$PUBKEY") (is it a public ssh-ed25519 key file?)"
    HOSTKEY=fail
  elif [ -z "$s_blob" ] || [ -z "$scan_fp" ]; then
    emit FAIL hostkey "sshd on $PI_IP gave no ed25519 host key (not up yet, or not the Pi?)"
    HOSTKEY=fail
  elif [ "$scan_fp" = "$want_fp" ]; then
    emit PASS hostkey "$scan_fp matches $(basename "$PUBKEY")"
    HOSTKEY=pass
  else
    emit FAIL hostkey "MISMATCH: $PI_IP presents $scan_fp but $(basename "$PUBKEY") is $want_fp. This is not the Pi you flashed (or the key on the card is not the pre-generated one). Do not copy any data to it."
    HOSTKEY=fail
  fi
else
  emit SKIP hostkey "no --expect-pubkey, so this cannot prove it is the freshly flashed Pi (scanned: ${scan_fp:-none})"
fi

# --- 3. known_hosts ---------------------------------------------------------------
kh_entries() { # "type blob" for every known_hosts entry of host $1
  [ -r "$KH" ] || return 0
  ssh-keygen -F "$1" -f "$KH" 2>/dev/null | grep -v '^#' | while read -r _ t b _; do printf '%s %s\n' "$t" "$b"; done
}
if [ -z "$s_blob" ]; then
  emit SKIP known_hosts "no host key was scanned, nothing to compare"
else
  stale=0 notes=()
  for h in "$PI_IP" "$PI_NAME"; do
    ents="$(kh_entries "$h")"
    if [ -z "$ents" ]; then
      notes+=("$h: no entry")
    elif printf '%s\n' "$ents" | grep -qxF "ssh-ed25519 $s_blob"; then
      notes+=("$h: matches")
    else
      notes+=("$h: STALE")
      stale=1
    fi
  done
  joined="$(IFS=,; echo "${notes[*]}")"
  if [ "$stale" -eq 0 ]; then
    emit PASS known_hosts "$joined"
  elif [ "$FIX_KH" -eq 1 ] && [ "$HOSTKEY" != fail ]; then
    ssh-keygen -R "$PI_IP" -f "$KH" >/dev/null 2>&1
    ssh-keygen -R "$PI_NAME" -f "$KH" >/dev/null 2>&1
    emit PASS known_hosts "removed the stale entries (ssh-keygen -R $PI_IP, ssh-keygen -R $PI_NAME; the previous file is kept as known_hosts.old)"
  elif [ "$FIX_KH" -eq 1 ]; then
    emit WARN known_hosts "${joined}; NOT fixed because the hostkey check failed (do not trust this Pi's key)"
  else
    emit WARN known_hosts "${joined}. ssh would refuse with REMOTE HOST IDENTIFICATION HAS CHANGED. Fix: ssh-keygen -R $PI_IP; ssh-keygen -R $PI_NAME (or rerun with --fix-known-hosts)"
  fi
fi

# --- 4. ssh -------------------------------------------------------------------------
SSH_OPTS=()
if [ "$HOSTKEY" = pass ]; then
  # Pin the session to the key just verified against the pre-generated one: no
  # reliance on (or writes to) ~/.ssh/known_hosts.
  printf '%s %s %s\n' "$PI_IP" "$s_type" "$s_blob" >"$TMP/pinned_known_hosts"
  SSH_OPTS=(-o "UserKnownHostsFile=$TMP/pinned_known_hosts" -o GlobalKnownHostsFile=/dev/null
    -o StrictHostKeyChecking=yes -o HostKeyAlgorithms=ssh-ed25519 -o UpdateHostKeys=no)
fi
vb_ssh() { # like pi_ssh, plus the pin above
  ssh -o BatchMode=yes -o ConnectTimeout="${PI_SSH_TIMEOUT:-10}" "${SSH_OPTS[@]}" "$PI_TARGET" "$@"
}
do_ssh() { vb_ssh true 2>"$TMP/ssh.err" </dev/null; }
SSH_OK=0
if [ "$HOSTKEY" = fail ]; then
  emit SKIP ssh "not connecting: the hostkey check failed, so whatever answers at $PI_IP is not the Pi you flashed"
elif poll do_ssh; then
  SSH_OK=1
  if [ "$HOSTKEY" = pass ]; then
    emit PASS ssh "$PI_TARGET reachable (session pinned to the verified host key)"
  else
    emit PASS ssh "$PI_TARGET reachable"
  fi
else
  err="$(head -n1 "$TMP/ssh.err" 2>/dev/null)"
  hint=""
  [ "$HOSTKEY" = pass ] || hint=" (without --expect-pubkey ssh needs this host's key already in known_hosts)"
  emit FAIL ssh "cannot ssh to $PI_TARGET: ${err:-no error text}$hint"
fi

# --- 5. one batched read-only probe session ----------------------------------------
decl() { local n="$1"; shift; printf '%s=(' "$n"; [ $# -eq 0 ] || printf '%q ' "$@"; printf ')\n'; }
build_probe() {
  printf 'set -uo pipefail\n'
  decl UNITS "${UNITS[@]}"; decl URLS "${URLS[@]}"; decl SECRETS "${SECRETS[@]}"; decl LINKS "${LINKS[@]}"
  cat <<'EOS'
p() { local t="$1" v; shift; printf '@%s' "$t"; for v in "$@"; do printf '\t%s' "${v:--}"; done; printf '\n'; }
main() {
  local out rc u d s st code nm rs pk rb db
  out="$(systemctl --failed --plain --no-legend 2>/dev/null)"; rc=$?
  p failed_rc "$rc"
  while read -r u _; do [ -n "$u" ] && p failed "$u"; done <<<"$out"
  p sys "$(readlink -f /run/current-system 2>/dev/null)"
  rs="$(findmnt -n -o SOURCE / 2>/dev/null)"
  pk="$(lsblk -no PKNAME "$rs" 2>/dev/null | head -n1 | tr -d '[:space:]')"
  rb="$(lsblk -bndo SIZE "$rs" 2>/dev/null | head -n1 | tr -d '[:space:]')"
  db=""; [ -n "$pk" ] && db="$(lsblk -bndo SIZE "/dev/$pk" 2>/dev/null | head -n1 | tr -d '[:space:]')"
  p root "$rs" "$pk" "$rb" "$db"
  p ts_active "$(systemctl is-active tailscaled 2>/dev/null)"
  p ts_addr "$(ip -o -4 addr show tailscale0 2>/dev/null | awk '{print $4}' | head -n1)"
  if command -v nmcli >/dev/null 2>&1; then
    p nmcli present
    nm="$(nmcli -t -f DEVICE,STATE device 2>/dev/null)"
    for d in "${LINKS[@]}"; do
      st="$(printf '%s\n' "$nm" | awk -F: -v d="$d" '$1==d{print $2; exit}')"
      p link "$d" "${st:-missing}"
    done
  else
    p nmcli absent
  fi
  if [ -d /var/log/journal ]; then p journal yes; else p journal no; fi
  for s in "${SECRETS[@]}"; do
    if [ -e "/run/secrets/$s" ]; then p secret "$s" yes; else p secret "$s" no; fi
  done
  for u in "${UNITS[@]}"; do p unit "$u" "$(systemctl is-active "$u" 2>/dev/null)"; done
  for u in "${URLS[@]}"; do
    if command -v curl >/dev/null 2>&1; then
      code="$(curl -sS -m 10 -o /dev/null -w '%{http_code}' "$u" 2>/dev/null)"; rc=$?
    else
      code=""; rc=127
    fi
    p url "$u" "$code" "$rc"
  done
  p done 1
}
main </dev/null
EOS
}

FAILED_RC="" FAILED=() SYS="" ROOT_SRC="" ROOT_PK="" ROOT_B="" DISK_B="" TS_ACTIVE="" TS_ADDR=""
NMCLI="" JOURNAL="" GOT_DONE=0 PRC=0
declare -A LINKST=() SECRETST=() UNITST=() URLCODE=() URLRC=()
if [ "$SSH_OK" -eq 1 ]; then
  probe="$(vb_ssh bash -s <<<"$(build_probe)" 2>"$TMP/probe.err")"; PRC=$?
  while IFS=$'\t' read -r tag a b c d; do
    for v in a b c d; do [ "${!v}" != "-" ] || printf -v "$v" '%s' ""; done
    case "$tag" in
      @failed_rc) FAILED_RC="$a" ;;
      @failed) FAILED+=("$a") ;;
      @sys) SYS="$a" ;;
      @root) ROOT_SRC="$a" ROOT_PK="$b" ROOT_B="$c" DISK_B="$d" ;;
      @ts_active) TS_ACTIVE="$a" ;;
      @ts_addr) TS_ADDR="$a" ;;
      @nmcli) NMCLI="$a" ;;
      @link) LINKST["$a"]="$b" ;;
      @journal) JOURNAL="$a" ;;
      @secret) SECRETST["$a"]="$b" ;;
      @unit) UNITST["$a"]="$b" ;;
      @url) URLCODE["$a"]="$b"; URLRC["$a"]="$c" ;;
      @done) GOT_DONE=1 ;;
    esac
  done <<<"$probe"
  if [ "$GOT_DONE" -ne 1 ]; then
    emit FAIL probes "the probe session ended early (ssh exit $PRC: $(head -n1 "$TMP/probe.err" 2>/dev/null)); results below may be incomplete"
  fi

  # failed units
  if [ -z "$FAILED_RC" ]; then
    emit WARN failed-units "no answer from systemctl --failed"
  elif [ "${#FAILED[@]}" -eq 0 ]; then
    emit PASS failed-units "none"
  else
    emit FAIL failed-units "${#FAILED[@]} failed: $(IFS=,; echo "${FAILED[*]}"). Look with: ssh $PI_TARGET journalctl -u <unit> -b"
  fi

  # running system
  if [ -n "$SYS" ]; then emit PASS system "running $SYS"; else emit WARN system "could not read /run/current-system"; fi

  # root partition expansion
  if [[ "$ROOT_B" =~ ^[0-9]+$ ]] && [[ "$DISK_B" =~ ^[0-9]+$ ]] && [ "$DISK_B" -gt 0 ]; then
    pct=$((ROOT_B * 100 / DISK_B))
    if [ $((ROOT_B * 100)) -ge $((DISK_B * 90)) ]; then
      emit PASS root-fs "$ROOT_SRC is $((ROOT_B / 1048576)) MiB of a $((DISK_B / 1048576)) MiB disk ($pct%), expanded"
    else
      partnum="${ROOT_SRC##*[!0-9]}"
      emit FAIL root-fs "$ROOT_SRC is only $((ROOT_B / 1048576)) MiB of a $((DISK_B / 1048576)) MiB disk ($pct%): the expand-root-partition step did not run. Fix on the Pi, as root: echo ',+,' | sfdisk -N$partnum --no-reread /dev/$ROOT_PK; partx -u /dev/$ROOT_PK; resize2fs $ROOT_SRC"
    fi
  else
    emit WARN root-fs "could not read the root partition and disk sizes (root=${ROOT_SRC:-?}, disk=${ROOT_PK:-?})"
  fi

  # tailscale
  if [ "$TS_ACTIVE" = active ] && [ -n "$TS_ADDR" ]; then
    emit PASS tailscale "tailscaled active, tailscale0 has ${TS_ADDR%%/*}"
  else
    emit FAIL tailscale "tailscaled is '${TS_ACTIVE:-unknown}' and tailscale0 address is '${TS_ADDR:-none}' (tailnet identity not restored? see the runbook's tailscale step)"
  fi

  # links
  for d in "${LINKS[@]}"; do
    if [ "$NMCLI" = absent ]; then
      emit SKIP "link:$d" "nmcli is not installed on the Pi, cannot check the link"
    else
      st="${LINKST[$d]:-}"
      case "$st" in
        connected | "connected ("*) emit PASS "link:$d" "connected" ;;
        *) emit FAIL "link:$d" "state '${st:-unknown}' (missing means no such device)" ;;
      esac
    fi
  done

  # journald
  case "$JOURNAL" in
    yes) emit PASS journald "persistent (/var/log/journal exists)" ;;
    no) emit WARN journald "volatile: /var/log/journal is missing, logs will vanish on power loss" ;;
    *) emit WARN journald "no answer" ;;
  esac

  # secrets (existence only)
  for s in "${SECRETS[@]}"; do
    case "${SECRETST[$s]:-}" in
      yes) emit PASS "secret:$s" "/run/secrets/$s exists (existence only; never read)" ;;
      *) emit FAIL "secret:$s" "/run/secrets/$s is missing: sops did not decrypt it. Does the Pi's host key match the age recipient in .sops.yaml?" ;;
    esac
  done

  # units
  for u in "${UNITS[@]}"; do
    st="${UNITST[$u]:-unknown}"
    if [ "$st" = active ]; then emit PASS "unit:$u" "active"; else emit FAIL "unit:$u" "state '$st'. Look with: ssh $PI_TARGET journalctl -u $u -b"; fi
  done

  # urls (curl ran on the Pi)
  for u in "${URLS[@]}"; do
    code="${URLCODE[$u]:-}"
    shown="${u%%\?*}"
    if [[ "$code" =~ ^[23][0-9][0-9]$ ]]; then
      emit PASS "url:$shown" "HTTP $code (curl on the Pi)"
    else
      emit FAIL "url:$shown" "HTTP '${code:-none}', curl exit ${URLRC[$u]:-?} (000 = connection refused or timed out; 127 = no curl on the Pi)"
    fi
  done
else
  emit SKIP remote-probes "no ssh session, so the failed-unit, disk, tailscale, secret, unit and url checks did not run"
fi

if [ "$NFAIL" -gt 0 ]; then
  echo "RESULT: FAIL ($NFAIL fail, $NWARN warn)"
  exit 1
fi
echo "RESULT: PASS ($NFAIL fail, $NWARN warn)"
