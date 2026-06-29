#!/usr/bin/env bash
set -euo pipefail

# Rotate session-summary.md for the session-closer skill.
# Keeps the ~5 most recent `## Session:` entries in the active
# file and moves any older entries into session-summary-archive.md
# (most-recent-first, same delimiter). Idempotent: a no-op when
# there are <= KEEP entries.
#
# Run from the repo root (or pass it as $1).

keep="${KEEP:-5}"
root="${1:-.}"
active="${root%/}/session-summary.md"
archive="${root%/}/session-summary-archive.md"
pointer='_Older entries are in [session-summary-archive.md](session-summary-archive.md)._'

if [ ! -f "$active" ]; then
  echo "No $active to rotate; nothing to do."
  exit 0
fi

# Count entries (delimiter is a line beginning with '## Session:').
total="$(grep -c '^## Session:' "$active" || true)"
if [ "$total" -le "$keep" ]; then
  echo "Only $total session entries (<= $keep) — no rotation needed."
  exit 0
fi

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

# Split the file into per-entry records on the '## Session:' delimiter,
# emitting the first $keep entries to the kept file and the rest to the
# archive. Any header/pointer preamble before the first entry is preserved.
awk -v keep="$keep" -v kept="$tmp.kept" -v old="$tmp.old" '
  /^## Session:/ { n++ }
  {
    if (n == 0) { print > (kept); next }   # preamble before first entry
    if (n <= keep) { print > (kept) } else { print > (old) }
  }
' "$active"

# Rebuild the active file: preamble (with pointer inserted just after the
# first heading line, or prepended if there is no heading) + kept entries.
: > "$tmp"
if grep -qF "$pointer" "$tmp.kept" 2>/dev/null; then
  cat "$tmp.kept" >> "$tmp"
else
  first_line="$(head -n1 "$tmp.kept")"
  if printf '%s' "$first_line" | grep -q '^#'; then
    { head -n1 "$tmp.kept"; printf '\n%s\n' "$pointer"; tail -n +2 "$tmp.kept"; } >> "$tmp"
  else
    { printf '%s\n\n' "$pointer"; cat "$tmp.kept"; } >> "$tmp"
  fi
fi
mv "$tmp" "$active"

# Prepend newly-archived entries ahead of any existing archive.
if [ -f "$archive" ]; then
  cat "$tmp.old" "$archive" > "$tmp.merge"
  mv "$tmp.merge" "$archive"
else
  mv "$tmp.old" "$archive"
fi

rm -f "$tmp.kept" "$tmp.old"
moved=$((total - keep))
echo "Rotated $moved older entr$( [ "$moved" -eq 1 ] && echo y || echo ies ) into $archive; kept $keep in $active."
