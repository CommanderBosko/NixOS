#!/usr/bin/env bash
# check-session-debt.sh — SessionStart hook.
#
# Nudge at the start of a new session if there are commits since the last
# session-closer close (a "chore(session): ..." commit) that were never
# narrated into project-state.md/session-summary.md/README.md — i.e. a
# prior session ran and committed without ever invoking /session-closer.
# See memory project_session_closer_gap_202607 for the recurring pattern
# this exists to surface (not prevent — catching up still works fine via
# transcripts/memory, this just makes the debt visible in real time instead
# of silently accumulating until the next close).
#
# Read-only: never edits/commits anything, just prints a systemMessage.
set -uo pipefail

cd /home/bosko/NixOS 2>/dev/null || exit 0

last_close="$(git log --oneline --grep='^chore(session):' -1 --format=%H 2>/dev/null)"

# No close ever recorded yet — nothing to compare against, stay quiet rather
# than guessing at a baseline.
[ -z "$last_close" ] && exit 0

n="$(git log "$last_close"..HEAD --oneline 2>/dev/null | wc -l | tr -d ' ')"

if [ "${n:-0}" -gt 0 ] 2>/dev/null; then
  plural="s"
  [ "$n" -eq 1 ] && plural=""
  msg="$n commit$plural since the last session-closer close — run /session-closer to catch this session up before it stacks with the next one."
  printf '%s' "$msg" | jq -Rs '{systemMessage: .}'
fi
