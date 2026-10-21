#!/usr/bin/env bash
# linecount: print the line count of each file argument, then a total.
set -u

total=0
status=0
for f in "$@"; do
  if [ ! -r "$f" ]; then
    echo "linecount: cannot read $f" >&2
    status=1
    continue
  fi
  n=$(wc -l < "$1")
  echo "$n $f"
  total=$((total + n))
done
echo "$total total"
exit "$status"
