#!/usr/bin/env bash
# plant.sh <host|local>: install the throwaway hc-status user unit on a host, with its planted fault.
#
# The unit should serve ~/hc-net-ssh/www on 127.0.0.1:18474, but its ExecStart says 18447
# (digits swapped). Everything is user-level: ~/.config/systemd/user/hc-status.service and
# ~/hc-net-ssh/. No sudo. `local` runs the same commands on this machine without ssh.
# Undo with cleanup.sh. Host names resolve through .claude/hosts.json (resolve-host.sh).
set -euo pipefail
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
target="${1:-}"
[ -n "$target" ] || { echo "usage: plant.sh <host-alias|local>" >&2; exit 2; }
if [ "$target" = local ]; then
  SSH=""
else
  SSH=$("$HERE/../../../../lib/resolve-host.sh" "$target") || { echo "unknown host '$target'" >&2; exit 2; }
fi
on_target() {
  if [ -z "$SSH" ]; then bash -s; else ssh -o BatchMode=yes -o ConnectTimeout=10 "$SSH" bash -s; fi
}

on_target <<'REMOTE'
set -euo pipefail
UNIT=hc-status.service
D="$HOME/hc-net-ssh"
UD="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
systemctl --user show-environment >/dev/null 2>&1 || { echo "plant: no user systemd manager on $(hostname)" >&2; exit 3; }
if [ -e "$UD/$UNIT" ] || [ -e "$D" ]; then
  echo "plant: already planted on $(hostname); run cleanup.sh first" >&2
  exit 4
fi
for p in 18474 18447; do
  if ss -ltnH "sport = :$p" | grep -q .; then echo "plant: port $p is busy on $(hostname)" >&2; exit 5; fi
done
PY=$(command -v python3 || true)
if [ -z "$PY" ]; then
  PY="$(nix build --no-link --print-out-paths nixpkgs#python3 2>/dev/null | head -n1)/bin/python3"
fi
[ -x "$PY" ] || { echo "plant: python3 not available on $(hostname)" >&2; exit 6; }

mkdir -p "$D/www" "$D/.orig" "$UD"
ls -1A "$UD" >"$D/.orig/user-dir.before"
[ -d "$UD/default.target.wants" ] || touch "$D/.orig/created-wants-dir"
cat >"$D/www/index.html" <<'HTML'
<!doctype html>
<html lang="en"><head><meta charset="utf-8"><title>Household status</title></head>
<body><h1>Household status</h1><p>HC-STATUS-PAGE-OK</p></body></html>
HTML
cat >"$UD/$UNIT" <<UNITFILE
[Unit]
Description=Household status page (should answer on 127.0.0.1:18474)

[Service]
Type=simple
WorkingDirectory=%h/hc-net-ssh/www
ExecStart=$PY -m http.server 18447 --bind 127.0.0.1
Restart=on-failure

[Install]
WantedBy=default.target
UNITFILE
cp "$UD/$UNIT" "$D/.orig/$UNIT"
sha256sum "$D/www/index.html" | cut -d' ' -f1 >"$D/.orig/index.sha256"
systemctl --user daemon-reload
systemctl --user enable --now "$UNIT" 2>/dev/null
sleep 1
echo "planted on $(hostname): $UNIT is $(systemctl --user is-active "$UNIT")"
REMOTE
