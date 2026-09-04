#!/usr/bin/env bash
# session-analysis mechanics: mode dispatch + deterministic manifest-building.
# The actual memory-worthy-content judgment (what's durable, what's a
# duplicate, what's just conversational noise) is Claude's job, done by
# fanning out transcript-scanner sub-agents over the manifest this script
# prints -- this script only does the deterministic file enumeration and
# cutoff filtering, reusing the shared lib scripts for the single-project
# mechanics rather than reimplementing them.
#
# Usage: scan-projects.sh <mode> [since-iso-timestamp]
#   mode                 dream (implemented) | time-analysis (not yet built --
#                        add a case arm here when it is; every other file in
#                        this skill dispatches on mode the same way)
#   since-iso-timestamp  optional ISO-8601 cutoff; omit (or pass "") for full
#                        history
#
# Ensures ~/.claude/dream/ exists (it does not by default). Prints a manifest
# to stdout, one block per project:
#   PROJECT: <real-path-or-UNKNOWN>
#   TRANSCRIPT_DIR: <path under ~/.claude/projects/>
#   TRANSCRIPTS_IN_SCOPE: <count>
#     <filename> (repeated, one per in-scope transcript, indented)
#   ---
set -uo pipefail

LIB_DIR="$HOME/.claude/skills/lib"
DREAM_DIR="$HOME/.claude/dream"

MODE="${1:?usage: scan-projects.sh <mode> [since-iso-timestamp]}"
SINCE="${2:-}"

mkdir -p "$DREAM_DIR"

case "$MODE" in
  dream)
    "$LIB_DIR/list-all-projects.sh" | while IFS=$'\t' read -r real_path transcript_dir; do
      [ -z "$transcript_dir" ] && continue
      echo "PROJECT: $real_path"
      echo "TRANSCRIPT_DIR: $transcript_dir"

      if [ "$real_path" = "UNKNOWN" ]; then
        echo "TRANSCRIPTS_IN_SCOPE: 0 (no .jsonl transcripts found -- memory-only project dir, nothing to mine)"
        echo "---"
        continue
      fi

      files="$("$LIB_DIR/list-transcripts-since.sh" "$SINCE" "$real_path" 2>/dev/null)"
      count=0
      [ -n "$files" ] && count="$(printf '%s\n' "$files" | grep -c .)"
      echo "TRANSCRIPTS_IN_SCOPE: $count"
      if [ "$count" -gt 0 ]; then
        printf '%s\n' "$files" | sed 's/^/  /'
      fi
      echo "---"
    done
    ;;
  time-analysis)
    echo "time-analysis mode is not implemented yet." >&2
    exit 2
    ;;
  *)
    echo "Unknown mode: $MODE (known modes: dream)" >&2
    exit 2
    ;;
esac
