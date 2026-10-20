#!/usr/bin/env bash
# cleanup.sh <host|local>: remove everything plant.sh (or the session) left on the host: the
# hc-status user unit and any drop-ins, its default.target.wants link, stray http.server copies
# on 18474/18447 serving ~/hc-net-ssh, and ~/hc-net-ssh. Idempotent. No sudo.
set -euo pipefail
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
target="${1:-}"
[ -n "$target" ] || { echo "usage: cleanup.sh <host-alias|local>" >&2; exit 2; }
if [ "$target" = local ]; then
  SSH=""
else
  SSH=$("$HERE/../../../../lib/resolve-host.sh" "$target") || { echo "unknown host '$target'" >&2; exit 2; }
fi
on_target() {
  if [ -z "$SSH" ]; then bash -s; else ssh -o BatchMode=yes -o ConnectTimeout=10 "$SSH" bash -s; fi
}

on_target <<'REMOTE'
set -uo pipefail
UNIT=hc-status.service
D="$HOME/hc-net-ssh"
UD="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
created_wants=0
[ -f "$D/.orig/created-wants-dir" ] && created_wants=1
systemctl --user disable --now "$UNIT" >/dev/null 2>&1
rm -f "$UD/$UNIT" "$UD/default.target.wants/$UNIT"
rm -rf "$UD/$UNIT.d"
[ $created_wants = 1 ] && rmdir "$UD/default.target.wants" 2>/dev/null
systemctl --user daemon-reload
systemctl --user reset-failed "$UNIT" >/dev/null 2>&1
for p in $(ss -ltnpH 'sport = :18474 or sport = :18447' 2>/dev/null | grep -o 'pid=[0-9]*' | cut -d= -f2 | sort -u); do
  case "$(readlink "/proc/$p/cwd" 2>/dev/null)" in
    "$D"*) kill "$p" 2>/dev/null ;;
  esac
done
rm -rf "$D"
sleep 0.5
left=""
systemctl --user list-unit-files "$UNIT" --no-legend 2>/dev/null | grep -q . && left="$left unit-file"
systemctl --user list-units --all "$UNIT" --no-legend 2>/dev/null | grep -q . && left="$left loaded-unit"
ss -ltnH 'sport = :18474 or sport = :18447' 2>/dev/null | grep -q . && left="$left listener"
[ -e "$D" ] && left="$left ~/hc-net-ssh"
if [ -n "$left" ]; then
  echo "cleanup on $(hostname): still present:$left" >&2
  exit 1
fi
echo "cleanup on $(hostname): nothing left"
REMOTE
