#!/usr/bin/env bash
# check-settings-diff.sh — Decide whether a change to .claude/settings.json stays
# inside the weekly routine's auto-apply boundary: purely additive entries in
# `permissions.allow`, and nothing else.
#
# Usage: check-settings-diff.sh <base.json> <head.json>
# Pure local check: reads the two files, never touches the network or the repo.
#
# Boundary (all must hold):
#   - everything outside `permissions.allow` (deny, ask, hooks, env, ...) is identical
#   - no existing allow entry is removed
#   - every added entry is either `mcp__<server>__<tool>` or a scoped `Bash(<cmd>)`
#     whose argument does not start with `*` and has no `;` `|` `&` backtick `$(`
#     (so the routine can't land `Bash(*)`, a bare `Bash`, or a chained command)
#
# Exit codes:
#   0 — boundary holds; prints one `ADDED: <entry>` line per new entry
#   1 — boundary broken or input unreadable; prints one `REASON: <why>` line
set -uo pipefail

fail() {
  echo "REASON: $1"
  exit 1
}

[ $# -eq 2 ] || fail "usage: check-settings-diff.sh <base.json> <head.json>"
BASE=$1
HEAD=$2

for f in "$BASE" "$HEAD"; do
  jq -e . "$f" > /dev/null 2>&1 || fail "not valid JSON: $f"
  jq -e '(.permissions.allow // []) | type == "array" and all(type == "string")' "$f" > /dev/null 2>&1 \
    || fail "permissions.allow is not an array of strings: $f"
done

[ "$(jq -S 'del(.permissions.allow)' "$BASE")" = "$(jq -S 'del(.permissions.allow)' "$HEAD")" ] \
  || fail "changes outside permissions.allow"

REMOVED=$(jq -r --slurpfile b "$BASE" '($b[0].permissions.allow // []) - (.permissions.allow // []) | .[]' "$HEAD")
[ -z "$REMOVED" ] || fail "removes allow entries: $(echo "$REMOVED" | paste -sd, -)"

ADDED=$(jq -r --slurpfile b "$BASE" '(.permissions.allow // []) - ($b[0].permissions.allow // []) | .[]' "$HEAD")

while IFS= read -r entry; do
  [ -z "$entry" ] && continue
  if [[ "$entry" =~ ^(Bash\([^*\)][^\)]*\)|mcp__[A-Za-z0-9_-]+)$ ]] \
    && [[ "$entry" != *[\;\|\&\`]* ]] && [[ "$entry" != *'$('* ]]; then
    continue
  fi
  fail "added allow entry outside the boundary: $entry"
done <<< "$ADDED"

while IFS= read -r entry; do
  [ -z "$entry" ] && continue
  echo "ADDED: $entry"
done <<< "$ADDED"
exit 0
