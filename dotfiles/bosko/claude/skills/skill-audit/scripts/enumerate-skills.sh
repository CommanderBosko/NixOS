#!/usr/bin/env bash
set -euo pipefail

# Enumerate every skill in the project for the skill-audit skill.
# Iterates the two skill locations (project-local .claude/skills and
# repo-owned dotfiles/*/claude/skills) and prints, per skill, its
# name, SKILL.md line count, and any sibling files (scripts/, assets/,
# config.json, ...). Run from the repo root.

for base in .claude/skills dotfiles/*/claude/skills; do
  [ -d "$base" ] || continue
  for d in "$base"/*/; do
    [ -f "$d/SKILL.md" ] || continue
    n=$(basename "$d"); extras=$(ls "$d" | grep -v '^SKILL.md$' | paste -sd, - || true)
    printf '%-24s %4s lines  [%s]\n' "$n" "$(wc -l <"$d/SKILL.md")" "$extras"
  done
done
