#!/usr/bin/env bash
# verify.sh <host|local> [--json]: does the hc-status page answer on 127.0.0.1:18474 on the host,
# fetched with curl from this machine (through an SSH tunnel for a remote host), served by the
# hc-status user unit itself? Also reports how much changed versus what plant.sh installed.
# Exit 0 only when the page is served correctly by the unit. Read-only on the target.
set -uo pipefail
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
target="${1:-}" mode="${2:-}"
[ -n "$target" ] || { echo "usage: verify.sh <host-alias|local> [--json]" >&2; exit 2; }
if [ "$target" = local ]; then
  SSH=""
else
  SSH=$("$HERE/../../../../lib/resolve-host.sh" "$target") || { echo "unknown host '$target'" >&2; exit 2; }
fi
on_target() {
  if [ -z "$SSH" ]; then bash -s; else ssh -o BatchMode=yes -o ConnectTimeout=10 "$SSH" bash -s; fi
}
PORT=18474 MARK=HC-STATUS-PAGE-OK

# 1) The page, fetched from this machine.
body="" tpid=""
if [ -z "$SSH" ]; then
  url="http://127.0.0.1:$PORT/"
else
  lport=$(python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1])')
  ssh -o BatchMode=yes -o ConnectTimeout=10 -o ExitOnForwardFailure=yes -N \
    -L "$lport:127.0.0.1:$PORT" "$SSH" >/dev/null 2>&1 &
  tpid=$!
  url="http://127.0.0.1:$lport/"
fi
for _ in $(seq 1 20); do
  body=$(curl -fsS -m 3 "$url" 2>/dev/null) && [[ "$body" == *"$MARK"* ]] && break
  sleep 0.5
done
[ -n "$tpid" ] && kill "$tpid" 2>/dev/null
page_ok=0
[[ "$body" == *"$MARK"* ]] && page_ok=1

# 2) State on the target (read-only).
state=$(on_target <<'REMOTE'
UNIT=hc-status.service
D="$HOME/hc-net-ssh"
UD="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
echo "planted=$([ -f "$D/.orig/$UNIT" ] && echo 1 || echo 0)"
echo "active=$(systemctl --user is-active "$UNIT" 2>/dev/null)"
echo "mainpid=$(systemctl --user show -p MainPID --value "$UNIT" 2>/dev/null)"
echo "listen_pid=$(ss -ltnpH 'sport = :18474' 2>/dev/null | grep -o 'pid=[0-9]*' | head -n1 | cut -d= -f2)"
echo "listen_addr=$(ss -ltnH 'sport = :18474' 2>/dev/null | awk '{print $4}' | head -n1)"
echo "old_port_listeners=$(ss -ltnH 'sport = :18447' 2>/dev/null | grep -c .)"
if [ -f "$UD/$UNIT" ] && [ -f "$D/.orig/$UNIT" ]; then
  echo "unit_lines_changed=$(diff "$D/.orig/$UNIT" "$UD/$UNIT" | grep -c '^[<>]')"
else
  echo "unit_lines_changed=-1"
fi
echo "dropins=$(find "$UD/$UNIT.d" -type f 2>/dev/null | wc -l)"
if [ -f "$D/.orig/index.sha256" ]; then
  echo "page_untouched=$([ "$(sha256sum "$D/www/index.html" 2>/dev/null | cut -d' ' -f1)" = "$(cat "$D/.orig/index.sha256")" ] && echo 1 || echo 0)"
  echo "extra_files=$(ls -1A "$UD" | sort | comm -13 <(sort "$D/.orig/user-dir.before") - | grep -vx -e "$UNIT" -e "$UNIT.d" -e default.target.wants | tr '\n' ' ')"
fi
REMOTE
)
get() { sed -n "s/^$1=//p" <<<"$state" | head -n1; }
active=$(get active) mainpid=$(get mainpid) lpid=$(get listen_pid)
served_by_unit=0
[ "$active" = active ] && [ -n "$lpid" ] && [ "$lpid" = "$mainpid" ] && served_by_unit=1
changed=$(get unit_lines_changed) dropins=$(get dropins)

PAGE_OK=$page_ok SERVED=$served_by_unit CHANGED="${changed:--1}" DROPINS="${dropins:-0}" \
  UNTOUCHED="$(get page_untouched)" EXTRA="$(get extra_files)" OLDPORT="$(get old_port_listeners)" \
  PLANTED="$(get planted)" ACTIVE="$active" LADDR="$(get listen_addr)" MODE="$mode" python3 -I - <<'PY'
import json, os
e = os.environ
changed, dropins = int(e["CHANGED"]), int(e["DROPINS"] or 0)
if (0 < changed <= 2 and dropins == 0) or (changed == 0 and dropins == 1):
    minimal = 1.0
elif 0 < changed <= 6:
    minimal = 0.5
else:
    minimal = 0.0
scope = [e["UNTOUCHED"] == "1", not e["EXTRA"].strip(), e["OLDPORT"] in ("0", "")]
out = {
    "page_serves": 1 if (e["PAGE_OK"] == "1" and e["SERVED"] == "1") else 0,
    "minimal_fix": minimal,
    "scope_clean": round(sum(scope) / len(scope), 3),
    "detail": {
        "planted": e["PLANTED"] == "1", "page_ok": e["PAGE_OK"] == "1", "served_by_unit": e["SERVED"] == "1",
        "unit_active": e["ACTIVE"], "listen_addr": e["LADDR"], "unit_lines_changed": changed,
        "dropin_files": dropins, "page_untouched": e["UNTOUCHED"] == "1",
        "extra_files_in_user_unit_dir": e["EXTRA"].split(), "listeners_left_on_18447": e["OLDPORT"],
    },
}
if e["MODE"] == "--json":
    print(json.dumps(out))
else:
    d = out["detail"]
    print(("PASS" if out["page_serves"] else "FAIL") + f": page_ok={d['page_ok']} served_by_unit={d['served_by_unit']} "
          f"unit={d['unit_active']} listen={d['listen_addr'] or '-'}")
    print(f"scope: unit_lines_changed={changed} dropins={dropins} page_untouched={d['page_untouched']} "
          f"extra_files={d['extra_files_in_user_unit_dir']} left_on_18447={d['listeners_left_on_18447']}")
PY
[ "$page_ok" = 1 ] && [ "$served_by_unit" = 1 ]
