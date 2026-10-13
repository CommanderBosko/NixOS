#!/usr/bin/env bash
# Scopes a skill's log review to "everything since this skill last ran" in one
# call. Wraps the two-step chain skill-audit, skill-suggestion, and
# skill-upgrade each used to type out by hand:
#   find-last-skill-invocation.sh <skill>  ->  list-transcripts-since.sh <cutoff>
# It only calls those scripts (plus find-transcript-dir.sh for the dir line);
# all detection and filtering logic stays in them.
#
# Usage: scope-since-last-run.sh <skill-name> [project-dir]
#   skill-name   the skill whose previous run sets the cutoff (e.g. skill-audit)
#   project-dir  defaults to $PWD
#
# Prints, on stdout:
#   cutoff: <iso-8601 timestamp>   previous invocation of <skill-name>, or
#   cutoff: none                   first-ever run -- the list is full history
#   transcript-dir: <path>         the dir the filenames below live in
#   <file>.jsonl                   one per line, newest first (may be none)
#
# Exits 1 (message on stderr) if the project has no transcript directory.
set -uo pipefail

SKILL_NAME="${1:?usage: scope-since-last-run.sh <skill-name> [project-dir]}"
PROJECT_DIR="${2:-$PWD}"

LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TRANSCRIPT_DIR="$("$LIB_DIR/find-transcript-dir.sh" "$PROJECT_DIR")" || exit 1

CUTOFF="$("$LIB_DIR/find-last-skill-invocation.sh" "$SKILL_NAME" "$PROJECT_DIR")"
FILES="$("$LIB_DIR/list-transcripts-since.sh" "$CUTOFF" "$PROJECT_DIR")" || exit 1

echo "cutoff: ${CUTOFF:-none}"
echo "transcript-dir: $TRANSCRIPT_DIR"
[ -n "$FILES" ] && printf '%s\n' "$FILES"
exit 0
