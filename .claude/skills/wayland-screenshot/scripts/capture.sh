#!/usr/bin/env bash
set -euo pipefail

# Capture a screenshot of the live niri/Wayland session, optionally after
# launching a specific app fresh with the current session environment.
#
# Usage:
#   capture.sh <output.png>                          — screenshot current desktop state
#   capture.sh <output.png> <app> [env=val ...]       — kill any running instance of
#     <app>, relaunch it detached with the refreshed session env (plus any
#     given VAR=value overrides), wait for it to render, then capture.

if [ "$#" -lt 1 ]; then
  echo "usage: capture.sh <output.png> [app] [env=val ...]" >&2
  exit 2
fi

out="$1"
shift
app="${1:-}"
[ "$#" -gt 0 ] && shift

# A tool-invoked shell can carry a stale environment from before the last
# `nixos-rebuild switch` — refresh it before launching anything. Disable
# nounset while sourcing: /etc/set-environment references vars (e.g.
# XDG_STATE_HOME) that aren't always already set in a tool-invoked shell.
set +u
# shellcheck disable=SC1091
source /etc/set-environment
set -u

if [ -n "$app" ]; then
  existing_pid="$(pgrep -x "$app" | head -1 || true)"
  if [ -n "$existing_pid" ]; then
    kill "$existing_pid"
    sleep 1
  fi
  nohup env "$@" "$app" > "/tmp/${app}.log" 2>&1 &
  disown
  sleep 2
fi

grim "$out"
echo "Saved to $out"
