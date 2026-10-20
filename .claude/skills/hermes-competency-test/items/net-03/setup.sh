#!/usr/bin/env bash
# net-03 setup: start the status-page server exactly as the fixture unit runs it
# (python3 http.server on 18473, bound to 127.0.0.1). Idempotent; records its PID in $RUN_DIR/pids.
set -euo pipefail
: "${RUN_DIR:?}" "${SANDBOX:?}"
PORT=18473
pidfile="$RUN_DIR/net-03.server.pid"
mkdir -p "$RUN_DIR"
port_busy() { ss -ltnH "sport = :$PORT" | grep -q .; }

if [ -s "$pidfile" ] && kill -0 "$(cat "$pidfile")" 2>/dev/null && port_busy; then
  grep -qx "$(cat "$pidfile")" "$RUN_DIR/pids" 2>/dev/null || cat "$pidfile" >>"$RUN_DIR/pids"
  exit 0
fi
for _ in $(seq 1 40); do port_busy || break; sleep 0.25; done
if port_busy; then
  echo "net-03 setup: port $PORT is already in use" >&2
  exit 1
fi

cd "$SANDBOX/task/www"
nohup python3 -m http.server "$PORT" --bind 127.0.0.1 >"$RUN_DIR/net-03.server.log" 2>&1 </dev/null &
pid=$!
echo "$pid" >>"$RUN_DIR/pids"
echo "$pid" >"$pidfile"
awk '{print $22}' "/proc/$pid/stat" >"$RUN_DIR/net-03.server.start"
for _ in $(seq 1 40); do
  port_busy && exit 0
  sleep 0.25
done
echo "net-03 setup: server did not start listening on $PORT" >&2
exit 1
