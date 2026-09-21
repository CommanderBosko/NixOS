#!/usr/bin/env bash
set -euo pipefail

# Rotate project-state.md for the session-closer skill.
# Keeps the ~5 most recent blocks of the `## Current Project State` section in
# the active file and moves any older blocks into project-state-archive.md
# (most-recent-first, same block format). Idempotent: a no-op when there are
# <= KEEP blocks. Only that one section is touched — Current Goals, Recent
# Decisions, Known Issues, Next Steps and the file header stay exactly as-is.
#
# A "block" is one session's contribution to the section: it starts at a line
# beginning with `**` (the bold headline, e.g. `**2026-09-20 flake bump ...**`)
# and runs — bullets, paragraphs, tables and all — up to the next such line or
# the end of the section. Anything between the section heading and the first
# block (blank lines, the archive pointer) is preamble and is always kept.
#
# Run from the repo root (or pass it as $1).
#   KEEP=<n>     blocks to keep in the active file (default 5)
#   DRY_RUN=1    report what would move (line range + bytes) and change nothing

keep="${KEEP:-5}"
dry="${DRY_RUN:-0}"
root="${1:-.}"
active="${root%/}/project-state.md"
archive="${root%/}/project-state-archive.md"
heading='## Current Project State'
pointer='_Older blocks are in [project-state-archive.md](project-state-archive.md)._'

case "$keep" in
  ''|*[!0-9]*|0) echo "KEEP must be a positive integer (got '$keep')." >&2; exit 2 ;;
esac

if [ ! -f "$active" ]; then
  echo "No $active to rotate; nothing to do."
  exit 0
fi

if ! grep -qxF "$heading" "$active"; then
  echo "No '$heading' section in $active; nothing to do."
  exit 0
fi

# Count blocks inside the section (lines starting with '**' between the section
# heading and the next '## ' heading).
total="$(awk -v h="$heading" '
  $0 == h { insec = 1; next }
  insec && /^## / { insec = 0 }
  insec && /^\*\*/ { n++ }
  END { print n + 0 }
' "$active")"

if [ "$total" -le "$keep" ]; then
  echo "Only $total block(s) in '$heading' (<= $keep) — no rotation needed."
  exit 0
fi

tmp="$(mktemp)"
trap 'rm -f "$tmp" "$tmp".*' EXIT

: > "$tmp.kept"; : > "$tmp.old"; : > "$tmp.tail"   # awk only creates files it prints to

# Split the file by position: everything up to and including the first $keep
# blocks (plus all lines before the section) goes to .kept, blocks beyond that
# go to .old, and everything from the next '## ' heading on goes to .tail.
# .range records the original first/last line numbers of the archived blocks.
awk -v h="$heading" -v keep="$keep" -v kept="$tmp.kept" -v old="$tmp.old" \
    -v tail="$tmp.tail" -v range="$tmp.range" '
  $0 == h && !insec && !after { insec = 1; print > kept; next }
  insec && /^## / { insec = 0; after = 1 }
  after { print > tail; next }
  !insec { print > kept; next }
  /^\*\*/ { n++ }
  n <= keep { print > kept; next }
  { print > old; if (!first) first = NR; last = NR }
  END { print first " " last > range }
' "$active"

read -r first last < "$tmp.range"
old_bytes="$(wc -c < "$tmp.old" | tr -d ' ')"
moved=$((total - keep))
plural="blocks"; [ "$moved" -eq 1 ] && plural="block"

if [ "$dry" = "1" ]; then
  echo "DRY RUN — would rotate $moved older $plural (lines $first-$last of $active, $old_bytes bytes) into $archive; would keep $keep."
  echo "$active: $(wc -c < "$active" | tr -d ' ') bytes now -> ~$(( $(wc -c < "$active" | tr -d ' ') - old_bytes )) bytes after."
  exit 0
fi

# A block must end on a blank line so concatenated blocks stay separated.
[ -z "$(tail -n1 "$tmp.old")" ] || echo >> "$tmp.old"

# Rebuild the active file: kept content (with the archive pointer inserted just
# after the section heading if it isn't there yet) + the untouched tail.
if grep -qF "$pointer" "$tmp.kept"; then
  cat "$tmp.kept" "$tmp.tail" > "$tmp"
else
  awk -v h="$heading" -v p="$pointer" '
    { print }
    $0 == h && !done { print ""; print p; done = 1 }
  ' "$tmp.kept" > "$tmp"
  cat "$tmp.tail" >> "$tmp"
fi
mv "$tmp" "$active"

# Prepend newly-archived blocks ahead of any existing archive blocks, keeping
# the archive's own header (everything before its first '**' line) on top.
if [ -f "$archive" ]; then
  first_block="$(grep -n -m1 '^\*\*' "$archive" | cut -d: -f1 || true)"
  if [ -n "$first_block" ]; then
    { head -n "$((first_block - 1))" "$archive"; cat "$tmp.old"; tail -n "+$first_block" "$archive"; } > "$tmp.merge"
  else
    { cat "$archive"; cat "$tmp.old"; } > "$tmp.merge"
  fi
  mv "$tmp.merge" "$archive"
else
  {
    printf '# Project State Archive\n\n'
    printf 'Older `%s` blocks rotated out of [project-state.md](project-state.md) by session-closer, most recent first. Git history holds every pre-rotation version of that file.\n\n' "${heading#\#\# }"
    cat "$tmp.old"
  } > "$archive"
fi

echo "Rotated $moved older $plural (lines $first-$last, $old_bytes bytes) into $archive; kept $keep in $active."
