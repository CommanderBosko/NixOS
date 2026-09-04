#!/usr/bin/env bash
# Posts a short summary + a file:// link back to a local file, to a Discord
# channel via an incoming webhook. Generic, minimal, stable contract -- any
# current or future skill can call this with just a file path and a summary
# string; it doesn't need to know or care who's calling it.
#
# Usage: post-discord.sh <file-path> <summary...>
#   file-path   absolute (or resolvable) path to the file being reported on.
#               Must exist -- this is a link back to a real artifact, not a
#               free-floating message.
#   summary     everything after the first argument, joined with spaces.
#               Free text; gets truncated with a note if it would blow past
#               Discord's message length cap.
#
# Reads the webhook URL from the sops-nix-managed secret at
# /run/secrets/discord-webhook-url (see send-results's SKILL.md Setup section
# for how that secret gets provisioned -- it involves a human creating a
# real Discord webhook, which this script cannot do for you). Exits non-zero
# with a clear, actionable message if the secret isn't there yet, if the
# target file doesn't exist, or if the POST itself fails.
#
# The file:// link only resolves when clicked from the same machine that ran
# this script -- accepted limitation, not a bug (see SKILL.md).
set -uo pipefail

SECRET_PATH="/run/secrets/discord-webhook-url"

if [ "$#" -lt 2 ]; then
  echo "usage: post-discord.sh <file-path> <summary...>" >&2
  exit 1
fi

FILE_PATH="$1"
shift
SUMMARY="$*"

if [ ! -f "$SECRET_PATH" ]; then
  cat >&2 <<'EOF'
Discord webhook secret not found at /run/secrets/discord-webhook-url -- it
hasn't been configured on this host yet.

See dotfiles/bosko/claude/skills/send-results/SKILL.md's Setup section: a
Discord webhook has to be created by a human (Discord server settings ->
Integrations -> Webhooks), then its URL added as a sops-nix secret via the
add-secret skill and wired into modules/sops.nix, then the host rebuilt.
EOF
  exit 1
fi

WEBHOOK_URL="$(cat "$SECRET_PATH" 2>/dev/null)"
if [ -z "$WEBHOOK_URL" ]; then
  echo "Discord webhook secret at $SECRET_PATH is empty." >&2
  exit 1
fi

if [ ! -e "$FILE_PATH" ]; then
  echo "File not found: $FILE_PATH" >&2
  exit 1
fi

ABS_PATH="$(readlink -f -- "$FILE_PATH" 2>/dev/null)"
[ -z "$ABS_PATH" ] && ABS_PATH="$FILE_PATH"
FILE_URL="file://$ABS_PATH"

# Discord's message content cap is 2000 chars; leave headroom for the link line.
MAX_SUMMARY=1800
if [ "${#SUMMARY}" -gt "$MAX_SUMMARY" ]; then
  SUMMARY="${SUMMARY:0:$MAX_SUMMARY}... (truncated)"
fi

CONTENT="$(printf '%s\n\n📄 %s' "$SUMMARY" "$FILE_URL")"

PAYLOAD="$(python3 -c '
import json, sys
print(json.dumps({"content": sys.argv[1]}))
' "$CONTENT")"

RESPONSE_FILE="$(mktemp)"
trap 'rm -f "$RESPONSE_FILE"' EXIT

HTTP_CODE="$(curl -sS -o "$RESPONSE_FILE" -w "%{http_code}" \
  -H "Content-Type: application/json" \
  -X POST \
  -d "$PAYLOAD" \
  "$WEBHOOK_URL" 2>/dev/null)" || HTTP_CODE="000"

BODY="$(cat "$RESPONSE_FILE" 2>/dev/null)"

if [ "$HTTP_CODE" -ge 200 ] 2>/dev/null && [ "$HTTP_CODE" -lt 300 ]; then
  echo "Posted to Discord (HTTP $HTTP_CODE)."
  exit 0
else
  echo "Discord webhook POST failed (HTTP $HTTP_CODE): $BODY" >&2
  exit 1
fi
