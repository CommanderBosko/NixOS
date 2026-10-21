#!/usr/bin/env bash
# logscan.sh: count how often PATTERN appears in the acme app's logs, archive the current logs,
# and keep only the newest KEEP archive files.
#
# Usage: logscan.sh PATTERN [KEEP]
#   PATTERN  extended regular expression, passed through exactly as the user typed it. On-call
#            people often search for option-like strings such as "-timeout" or "--retry".
#   KEEP     how many archive files to keep in total (default 14)
#
# Environment: LOG_DIR (default "/var/log/acme app"). logrotate truncates the logs separately;
# this script only reads them.
set -euo pipefail

LOG_DIR="${LOG_DIR:-/var/log/acme app}"
ARCHIVE_DIR="$LOG_DIR/archive"

if [ $# -lt 1 ] || [ $# -gt 2 ]; then
  echo "usage: logscan.sh PATTERN [KEEP]" >&2
  exit 2
fi
pattern="$1"
keep="${2:-14}"
if ! [[ "$keep" =~ ^[0-9]+$ ]]; then
  echo "KEEP must be a non-negative integer" >&2
  exit 2
fi

mkdir -p "$ARCHIVE_DIR"
stamp=$(date +%Y%m%d-%H%M%S)

# 1. Count matching lines per log file.
total=0
for log in "$LOG_DIR"/*.log; do
  [ -e "$log" ] || continue
  count=$(grep -cE "$pattern" "$log" || true)
  echo "$(basename "$log"): $count"
  total=$((total + count))
done
echo "total: $total"

# 2. Archive the current logs.
for log in "$LOG_DIR"/*.log; do
  [ -e "$log" ] || continue
  gzip -c $log > "$ARCHIVE_DIR/$(basename "$log" .log)-$stamp.log.gz"
done

# 3. Keep only the newest $keep archive files.
find "$ARCHIVE_DIR" -maxdepth 1 -name '*.log.gz' -printf '%T@ %p\n' \
  | sort -rn \
  | cut -d' ' -f2- \
  | tail -n +"$keep" \
  | while IFS= read -r old; do
      rm -f -- "$old"
    done
