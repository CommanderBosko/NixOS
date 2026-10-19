#!/usr/bin/env bash
# Enumerates every Claude Code project transcript directory under
# ~/.claude/projects/*/ and, for each, recovers the REAL project filesystem
# path by reading the `cwd` field out of one of its .jsonl transcripts --
# NOT by un-slugifying the directory name. Un-reversing `sed 's#/#-#g'` is
# not bijective: a real path segment containing a literal "-" (e.g.
# /home/bosko/projects/Codingame-Mad-Pod-Racing) collides with a path
# separator and un-slugifies wrong. Reading the ground-truth `cwd` field
# avoids that entirely. Only a `cwd` whose Claude Code slug (every
# non-alphanumeric char -> "-") equals the dir's own name is accepted: after a
# project rename, a dir's transcripts can record the OTHER name's cwd, and
# taking the first cwd blindly mapped renamed projects to each other's paths.
# If no cwd matches, a sibling dir of any recorded cwd whose slug matches is
# accepted instead (the project was renamed in place).
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
# A project whose dir holds no .jsonl with a slug-matching `cwd` field and no
# slug-matching renamed sibling (e.g. all transcripts have since been pruned
# but a memory/ dir remains) prints
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

  # shortcut: no handling of Claude Code's 200+ char slug truncation, so such paths stay UNKNOWN
  real_path="$(python3 - "$(basename "$dir")" "${jsonl_files[@]}" 2>/dev/null <<'PYEOF'
import json, os, re, sys

def slug(p):
    return re.sub(r'[^A-Za-z0-9]', '-', p)

want, seen = sys.argv[1], []
for fn in sys.argv[2:]:
    try:
        with open(fn) as fh:
            for line in fh:
                line = line.strip()
                if not line:
                    continue
                try:
                    obj = json.loads(line)
                except (ValueError, json.JSONDecodeError):
                    continue
                cwd = obj.get('cwd') if isinstance(obj, dict) else None
                if not cwd:
                    continue
                if slug(cwd) == want:
                    print(cwd)
                    sys.exit(0)
                if cwd not in seen:
                    seen.append(cwd)
    except OSError:
        pass

# Covers a project dir renamed in place: transcripts still record the old name.
for cwd in seen:
    try:
        entries = sorted(os.scandir(os.path.dirname(cwd)), key=lambda e: e.name)
    except OSError:
        continue
    for e in entries:
        if e.is_dir() and slug(e.path) == want:
            print(e.path)
            sys.exit(0)
PYEOF
)"

  printf '%s\t%s\n' "${real_path:-UNKNOWN}" "$dir"
done
