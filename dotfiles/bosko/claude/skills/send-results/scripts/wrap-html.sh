#!/usr/bin/env bash
# Wraps a text file as the minimal HTML page send-results publishes as an
# Artifact (Step 2). Fills assets/wrapper-template.html with the given title
# and the file's HTML-escaped content, writes the result, and prints its path.
#
# Usage: wrap-html.sh <file-path> <title> [out-path]
#   file-path  the file being reported on. Must exist.
#   title      short noun phrase naming the artifact, derived from the
#              filename by the caller (e.g. dream-test.txt -> "Dream Test",
#              overview-20260904.md -> "Memory Overview"). Goes into <title>.
#   out-path   optional. Defaults to
#              ~/.claude/dream/.artifact-staging/<basename-of-file-path>.html
#              so repeated calls don't collide with unrelated temp files.
#              The parent directory is created if it doesn't exist.
#
# What the template guarantees (keep these if you edit it): a <title>; the
# file's content in a <pre> with white-space: pre-wrap and a readable
# monospace font -- enough for a report/log/markdown file, don't over-invest
# in layout; artifact-design's theme rules (light/dark tokens via
# prefers-color-scheme plus [data-theme] overrides) and no horizontal page
# scroll, even for this minimal case. This is a notification attachment, not a
# designed deliverable.
set -uo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMPLATE="$SKILL_DIR/assets/wrapper-template.html"

if [ "$#" -lt 2 ] || [ "$#" -gt 3 ]; then
  echo "usage: wrap-html.sh <file-path> <title> [out-path]" >&2
  exit 1
fi

FILE="$1"
TITLE="$2"
OUT="${3:-$HOME/.claude/dream/.artifact-staging/$(basename "$FILE").html}"

if [ ! -f "$FILE" ]; then
  echo "wrap-html.sh: file not found: $FILE" >&2
  exit 1
fi

if [ -z "$TITLE" ]; then
  echo "wrap-html.sh: title must not be empty" >&2
  exit 1
fi

if [ ! -f "$TEMPLATE" ]; then
  echo "wrap-html.sh: template not found: $TEMPLATE" >&2
  exit 1
fi

mkdir -p "$(dirname "$OUT")" || exit 1

# One-pass substitution, so a title or file that itself contains a
# {{PLACEHOLDER}} string can't be re-expanded.
python3 -c '
import html, re, sys
template_path, src_path, title, out_path = sys.argv[1:5]
with open(template_path, encoding="utf-8") as f:
    template = f.read()
with open(src_path, encoding="utf-8", errors="replace") as f:
    content = f.read()
values = {
    "{{TITLE}}": html.escape(title),
    "{{CONTENT}}": html.escape(content, quote=False),
}
page = re.sub(r"\{\{(?:TITLE|CONTENT)\}\}", lambda m: values[m.group(0)], template)
with open(out_path, "w", encoding="utf-8") as f:
    f.write(page)
' "$TEMPLATE" "$FILE" "$TITLE" "$OUT" || {
  echo "wrap-html.sh: failed to write $OUT" >&2
  exit 1
}

echo "$OUT"
