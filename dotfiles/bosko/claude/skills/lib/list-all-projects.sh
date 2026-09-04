#!/usr/bin/env bash
# Enumerates every Claude Code project transcript directory under
# ~/.claude/projects/*/ and, for each, recovers the REAL project filesystem
# path by reading the `cwd` field out of one of its .jsonl transcripts --
# NOT by un-slugifying the directory name. Un-reversing `sed 's#/#-#g'` is
# not bijective: a real path segment containing a literal "-" (e.g.
# /home/bosko/projects/Codingame-Mad-Pod-Racing) collides with a path
# separator and un-slugifies wrong. Reading the ground-truth `cwd` field
# avoids that entirely.
#
# This is a *new* script rather than a change to find-transcript-dir.sh /
# list-transcripts-since.sh / find-last-skill-invocation.sh -- those three
# have an established single-project contract (take a project dir, resolve
# to one transcript dir) that other skills (session-closer, skill-suggestion,
# skill-upgrade, skill-audit, save-memory, research) already depend on.
# Printing the real path here lets callers feed it straight into those
# scripts unchanged instead of forking their contract.
#
# Usage: list-all-projects.sh
#
# Prints one line per project dir found under ~/.claude/projects/, tab-separated:
#   <real-project-path-or-UNKNOWN><TAB><transcript-dir>
#
# A project whose dir holds no .jsonl with a readable `cwd` field (e.g. all
# transcripts have since been pruned but a memory/ dir remains) prints
# "UNKNOWN" as its real path instead of guessing -- callers must handle that
# case explicitly (typically: still process memory/ dir, skip anything that
# needs the real project path such as CLAUDE.md discovery).
set -uo pipefail

PROJECTS_ROOT="$HOME/.claude/projects"
[ -d "$PROJECTS_ROOT" ] || exit 0

for dir in "$PROJECTS_ROOT"/*/; do
  dir="${dir%/}"
  [ -d "$dir" ] || continue

  real_path=""
  shopt -s nullglob
  jsonl_files=("$dir"/*.jsonl)
  shopt -u nullglob

  for f in "${jsonl_files[@]}"; do
    real_path="$(python3 -c "
import json, sys
try:
    with open(sys.argv[1]) as fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            try:
                obj = json.loads(line)
            except (ValueError, json.JSONDecodeError):
                continue
            cwd = obj.get('cwd')
            if cwd:
                print(cwd)
                break
except OSError:
    pass
" "$f" 2>/dev/null)"
    [ -n "$real_path" ] && break
  done

  printf '%s\t%s\n' "${real_path:-UNKNOWN}" "$dir"
done
