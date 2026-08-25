#!/usr/bin/env bash
#
# pihole-api.sh — Authenticate to the pi-hole host's local REST API and run
# one follow-up call against it, in a single SSH round-trip.
#
# Auth mechanics (ground truth from a real session, 2026-08-25):
#   PW=$(sudo -n cat /etc/pihole/cli_pw)
#   SID=$(curl -skS -X POST "http://127.0.0.1/api/auth" --data "{\"password\":\"${PW}\"}" | jq -r ".session.sid")
# The SID is then reused as a `sid:` header on the actual call. Auth is cheap
# to redo per invocation — no session caching across runs.
#
# Usage:
#   pihole-api.sh <METHOD> <path-with-query> [json-body]
#
# Examples:
#   pihole-api.sh GET  "/api/lists?type=block"
#   pihole-api.sh POST "/api/lists?type=block" '{"address":"https://example.com/list.txt","comment":"...","groups":[0],"enabled":true}'
#   pihole-api.sh PUT  "/api/lists/https%3A%2F%2Fexample.com%2Flist.txt?type=block" '{"enabled":false}'
#   pihole-api.sh DELETE "/api/lists/https%3A%2F%2Fexample.com%2Flist.txt?type=block"
#
# NOTE: `type` (block/allow) is a QUERY PARAM on /api/lists, never a JSON body
# field — putting it in the body fails with a "bad_request" error (learned
# live). Always include it in <path-with-query> when calling /api/lists.
#
# Prints the raw response body from the follow-up call to stdout.
# Exits 1 if the host can't be resolved, the CLI password can't be read, or
# no session ID is obtained.
#
# Used by the pihole-api skill.

set -uo pipefail

RESOLVE_HOST="/home/bosko/NixOS/.claude/lib/resolve-host.sh"

METHOD="${1:-}"
API_PATH="${2:-}"
BODY="${3:-}"

if [ -z "$METHOD" ] || [ -z "$API_PATH" ]; then
  echo "Usage: pihole-api.sh <METHOD> <path-with-query> [json-body]" >&2
  echo '  e.g. pihole-api.sh GET "/api/lists?type=block"' >&2
  exit 1
fi

TARGET="$(bash "$RESOLVE_HOST" pi-hole)"
RC=$?
if [ "$RC" -ne 0 ] || [ -z "$TARGET" ]; then
  echo "ERROR: could not resolve 'pi-hole' via $RESOLVE_HOST" >&2
  exit 1
fi

# Base64-encode every value before it crosses the ssh boundary: ssh joins the
# remote command's argv into one string and hands it to the remote shell for
# re-parsing, so a raw JSON body (quotes/braces/spaces) or query string
# (&/?/=) would otherwise be mis-tokenized — or worse, break out into extra
# commands. Base64 output is shell-metacharacter-free, so it survives intact.
METHOD_B64="$(printf '%s' "$METHOD" | base64 -w0)"
PATH_B64="$(printf '%s' "$API_PATH" | base64 -w0)"
BODY_B64="$(printf '%s' "$BODY" | base64 -w0)"

ssh -o ConnectTimeout=8 -o BatchMode=yes "$TARGET" bash -s -- "$METHOD_B64" "$PATH_B64" "$BODY_B64" <<'REMOTE'
set -uo pipefail
METHOD="$(printf '%s' "$1" | base64 -d)"
API_PATH="$(printf '%s' "$2" | base64 -d)"
BODY="$(printf '%s' "${3:-}" | base64 -d)"

PW=$(sudo -n cat /etc/pihole/cli_pw 2>/dev/null)
if [ -z "$PW" ]; then
  echo "ERROR: could not read /etc/pihole/cli_pw via 'sudo -n' — check passwordless sudo is still in place for bosko@pi-hole" >&2
  exit 1
fi

SID=$(curl -skS -X POST "http://127.0.0.1/api/auth" --data "{\"password\":\"${PW}\"}" | jq -r ".session.sid")
if [ -z "$SID" ] || [ "$SID" = "null" ]; then
  echo "ERROR: failed to obtain a session ID from /api/auth" >&2
  exit 1
fi

if [ -n "$BODY" ]; then
  curl -skS -X "$METHOD" "http://127.0.0.1${API_PATH}" -H "sid: ${SID}" -H "Content-Type: application/json" --data "$BODY"
else
  curl -skS -X "$METHOD" "http://127.0.0.1${API_PATH}" -H "sid: ${SID}"
fi
echo
REMOTE
