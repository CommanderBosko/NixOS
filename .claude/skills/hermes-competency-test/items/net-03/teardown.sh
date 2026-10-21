#!/usr/bin/env bash
# net-03 teardown: record whether setup's server process survived the session (same PID and
# start time), then stop any other copy left listening on the port so the next repeat starts
# clean. The runner kills setup's own PID afterwards.
set -uo pipefail
: "${RUN_DIR:?}"
PORT=18473
pid=$(cat "$RUN_DIR/net-03.server.pid" 2>/dev/null || true)
alive=no
if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null &&
  [ "$(awk '{print $22}' "/proc/$pid/stat" 2>/dev/null)" = "$(cat "$RUN_DIR/net-03.server.start" 2>/dev/null)" ]; then
  alive=yes
fi
{
  echo "alive=$alive"
  echo "pid=$pid"
} >"$RUN_DIR/net-03.server.state"
ss -ltnpH "sport = :$PORT" >"$RUN_DIR/net-03.listeners" 2>/dev/null

for p in $(grep -o 'pid=[0-9]*' "$RUN_DIR/net-03.listeners" | cut -d= -f2 | sort -u); do
  [ "$p" = "$pid" ] && continue
  if tr '\0' ' ' <"/proc/$p/cmdline" 2>/dev/null | grep -q "http.server"; then
    kill "$p" 2>/dev/null
  fi
done
exit 0
