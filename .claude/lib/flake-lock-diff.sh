#!/usr/bin/env bash
#
# flake-lock-diff.sh — Summarize flake.lock revision changes for /home/bosko/NixOS.
#
# Compares the committed flake.lock against the working-tree flake.lock and prints,
# for each root input whose locked `rev` changed, one aligned line:
#
#   <name>   <old8> -> <new8>   (<YYYY-MM-DD from new lastModified>)
#
# Inputs that didn't change are omitted. If nothing changed, prints
# "flake.lock unchanged." Inputs using `follows` (no `.locked`) are skipped.
#
# Usage:
#   flake-lock-diff.sh            # compare HEAD:flake.lock vs working-tree flake.lock
#   flake-lock-diff.sh <ref>      # compare <ref>:flake.lock vs working-tree flake.lock
#
# Used by the /update, /bump-input, and /pin-input skills.

set -uo pipefail

REPO=/home/bosko/NixOS
OLD_REF="${1:-HEAD}"

NEW_LOCK="$REPO/flake.lock"

OLD_JSON="$(git -C "$REPO" show "${OLD_REF}:flake.lock" 2>/dev/null)"
if [ -z "$OLD_JSON" ]; then
  echo "Error: could not read flake.lock from git ref '${OLD_REF}'." >&2
  exit 1
fi

# jq program: given old lock on stdin and new lock as $new, emit one line per
# root input whose resolved node's locked.rev differs. Resolves root input ->
# node name, skips nodes without .locked (follows-only), aligns columns.
JQ_PROG='
def resolve($lock; $name):
  $lock.nodes.root.inputs[$name] as $node
  | $lock.nodes[$node].locked;

. as $old
| ($new.nodes.root.inputs // {}) as $newinputs
| [ $newinputs | keys[] ] as $names
| $names
| map(. as $n
    | (resolve($old; $n)) as $o
    | (resolve($new; $n)) as $w
    | select($o != null and $w != null)
    | select(($o.rev // "") != ($w.rev // ""))
    | { name: $n,
        old: (($o.rev // "")[0:8]),
        new: (($w.rev // "")[0:8]),
        date: (($w.lastModified // 0) | gmtime | strftime("%Y-%m-%d")) }
  )
| if length == 0 then
    "flake.lock unchanged."
  else
    (map(.name | length) | max) as $w
    | map("  " + (.name + (" " * ($w - (.name | length))))
          + "   " + .old + " -> " + .new
          + "   (" + .date + ")")
    | .[]
  end
'

echo "$OLD_JSON" | jq -r --argjson new "$(cat "$NEW_LOCK")" "$JQ_PROG"
