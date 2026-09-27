#!/usr/bin/env bash
# Deterministic memory-hygiene checks for one project's memory dir.
#
# IMPORTANT distinction (see save-memory's own SKILL.md): "a link whose
# target doesn't exist yet is fine; it marks something worth writing later."
# So a [[wikilink]] with no matching file is very often *intentional*, not a
# bug -- it must never be silently auto-fixed or even flagged as broken.
# Only two things here are genuine staleness:
#   1. A MEMORY.md index line pointing at a file that doesn't exist (the
#      index is only ever written alongside the file itself, per
#      save-memory's Step 3 then Step 4 -- so a dangling index entry always
#      means something was renamed/removed without updating the index).
#   2. A [[wikilink]] whose target, after normalizing hyphens/underscores/case,
#      clearly matches an EXISTING file under a different spelling -- a
#      naming-convention typo, not a forward-reference.
# Anything else (a wikilink with no plausible match at all) is printed as
# informational only and must not be treated as auto-apply-tier cleanup.
#
# A [[slug]] link can resolve two different ways across this corpus, and
# BOTH count as a real, working link (checked before any fuzzy matching):
#   - against the target file's `name:` FRONTMATTER VALUE (the documented
#     convention: "link to the other memory's name: slug") -- used by
#     projects like farmer/screeps, where name: is often a shortened/
#     hyphenated form that differs from the filename (bones_farming.md has
#     `name: bones-farming`);
#   - against the target file's own FILENAME STEM verbatim -- the pattern
#     this repo's own NixOS memory dir actually uses in practice, where
#     `[[project_printer_browsed_fix]]` links directly to
#     project_printer_browsed_fix.md even though that file's `name:` is the
#     hyphenated `project-printer-browsed-fix`.
# Checking only one of these two (as an earlier version of this script did,
# filename-only) produces false positives against whichever project uses the
# other convention -- don't regress to a single-convention check. A file
# with no `name:` line at all just has its filename stem as its only slug.
#
# Usage: find-memory-issues.sh <project-memory-dir>
#
# Prints one finding per line:
#   DEAD_INDEX_LINK: MEMORY.md references <file> which does not exist
#   WIKILINK_NEAR_MISS: <file> contains [[<slug>]] -- likely means <actual-file> (auto-fixable)
#   WIKILINK_UNRESOLVED: <file> contains [[<slug>]] with no matching file (informational only -- may be an intentional forward-reference per save-memory's own convention; do NOT auto-fix or delete)
# Prints nothing if the dir doesn't exist or has no MEMORY.md (not an error --
# plenty of projects have no memory system at all).
set -uo pipefail

MEMORY_DIR="${1:?usage: find-memory-issues.sh <project-memory-dir>}"
INDEX="$MEMORY_DIR/MEMORY.md"

[ -d "$MEMORY_DIR" ] || exit 0
[ -f "$INDEX" ] || exit 0

normalize() {
  # lowercase, collapse - and _ to the same char, for near-miss comparison
  echo "$1" | tr 'A-Z' 'a-z' | tr '-' '_'
}

# --- MEMORY.md index lines: - [Title](slug_name.md) — hook text ---
grep -oE '\]\([A-Za-z0-9_.-]+\.md\)' "$INDEX" 2>/dev/null | sed -E 's/^\]\(//; s/\)$//' | sort -u | \
while IFS= read -r fname; do
  [ -f "$MEMORY_DIR/$fname" ] || echo "DEAD_INDEX_LINK: MEMORY.md references $fname which does not exist"
done

# --- [[slug]] links inside memory bodies ---
shopt -s nullglob
existing_files=("$MEMORY_DIR"/*.md)
shopt -u nullglob

# Each existing file has up to two valid exact-match slugs: its filename
# stem, and its `name:` frontmatter value (when present and different).
existing_stems=()
existing_names=()
for existing in "${existing_files[@]}"; do
  exbase="$(basename "$existing" .md)"
  existing_stems+=("$exbase")
  name_line="$(grep -m1 -E '^name:[[:space:]]*' "$existing" 2>/dev/null | sed -E 's/^name:[[:space:]]*//')"
  existing_names+=("$name_line")
done

for f in "${existing_files[@]}"; do
  base="$(basename "$f")"
  [ "$base" = "MEMORY.md" ] && continue
  grep -oE '\[\[[A-Za-z0-9_-]+\]\]' "$f" 2>/dev/null | sed -E 's/^\[\[//; s/\]\]$//' | sort -u | \
  while IFS= read -r slug; do
    resolved=""
    for i in "${!existing_files[@]}"; do
      if [ "$slug" = "${existing_stems[$i]}" ] || { [ -n "${existing_names[$i]}" ] && [ "$slug" = "${existing_names[$i]}" ]; }; then
        resolved="yes"
        break
      fi
    done
    if [ -n "$resolved" ]; then
      continue
    fi
    norm_slug="$(normalize "$slug")"
    match=""
    for i in "${!existing_files[@]}"; do
      if [ "$(normalize "${existing_stems[$i]}")" = "$norm_slug" ]; then
        match="${existing_stems[$i]}.md"
        break
      fi
      if [ -n "${existing_names[$i]}" ] && [ "$(normalize "${existing_names[$i]}")" = "$norm_slug" ]; then
        match="${existing_stems[$i]}.md"
        break
      fi
    done
    if [ -n "$match" ]; then
      echo "WIKILINK_NEAR_MISS: $base contains [[$slug]] -- likely means $match (auto-fixable)"
    else
      echo "WIKILINK_UNRESOLVED: $base contains [[$slug]] with no matching file (informational only -- may be an intentional forward-reference per save-memory's own convention; do NOT auto-fix or delete)"
    fi
  done
done
exit 0
