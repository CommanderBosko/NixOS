#!/usr/bin/env bash
# Step 5 helper: reads the consolidated report from stdin, writes it to
# ~/.claude/improve-system/report-<ts>.md, verifies it landed, prints the path.
# Usage: write-report.sh < report-body.md
# Exit: 0 = written and non-empty; 1 = stdin empty or write failed.
set -euo pipefail
dir="$HOME/.claude/improve-system"
mkdir -p "$dir"
out="$dir/report-$(date +%Y%m%d-%H%M%S).md"
cat > "$out"
[ -s "$out" ] || { echo "write-report: empty report, nothing written" >&2; rm -f "$out"; exit 1; }
echo "$out"
