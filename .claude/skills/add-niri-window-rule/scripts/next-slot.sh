#!/usr/bin/env bash
#
# next-slot.sh — Step 2 helper for the /add-niri-window-rule skill: lists the
# named workspace slots pinned to one output in a host's niri overlay, which
# app(s) each slot holds, and the next free slot name. Read-only.
#
# Parses hosts/<host>/niri-overlay.kdl (the host must be a desktop host in
# .claude/hosts.json):
#   - every top-level `workspace "<name>" { open-on-output "<connector>" }`
#   - every top-level `window-rule { match ...; open-on-workspace "<name>" }`
# A slot is "occupied" when at least one window-rule opens on it, "free"
# otherwise. The next new slot name follows the file's `<prefix>-<n>`
# convention (asus-1, dell-2, ...): the output's existing prefix, numbered one
# past the highest <prefix>-<n> anywhere in the file, so it never collides with
# a slot on another output.
#
# Usage:
#   next-slot.sh <host> <output> [prefix]
#
#   <host>    desktop host, e.g. gaming
#   <output>  connector name from `niri msg outputs`, e.g. HDMI-A-1
#   [prefix]  only needed when <output> has no slots yet, or its slots use
#             more than one prefix (the script says so); e.g. the monitor's
#             make from `niri msg outputs`, lowercased
#
# Output (stdout):
#   overlay: <path>
#   output: <connector>
#   slot <name>  <occupant match(es) | (free)>     one line per slot on <output>
#   free-slots: <names | none>
#   next-new-slot: <name | ? (reason)>
#   all-outputs: <connector>=<slot count> ...      every output with slots
#
# Exit codes: 0 report printed, 1 bad host / missing overlay, 2 usage.
#
# Example:
#   next-slot.sh gaming HDMI-A-1

set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
source "$REPO/.claude/lib/hosts.sh"

HOST="${1:-}"
OUTPUT="${2:-}"
PREFIX="${3:-}"

if [ -z "$HOST" ] || [ -z "$OUTPUT" ]; then
  echo "usage: next-slot.sh <host> <output> [prefix]" >&2
  exit 2
fi

if [ "$(hosts_jq -r --arg h "$HOST" '.hosts[$h].desktop // false')" != "true" ]; then
  echo "next-slot.sh: '$HOST' is not a desktop host in $HOSTS_JSON. Desktop hosts:" >&2
  hosts_jq -r '.hosts | to_entries[] | select(.value.desktop) | "  \(.key)"' >&2
  exit 1
fi

OVERLAY="$REPO/hosts/$HOST/niri-overlay.kdl"
if [ ! -f "$OVERLAY" ]; then
  echo "next-slot.sh: no overlay file at $OVERLAY" >&2
  exit 1
fi

echo "overlay: $OVERLAY"
echo "output: $OUTPUT"

awk -v want="$OUTPUT" -v prefix_arg="$PREFIX" '
  # Strip quoted strings (raw r#"..."# first) so braces inside them are not counted.
  function strip(s) { gsub(/r#"[^"]*"#/, "", s); gsub(/"[^"]*"/, "", s); sub(/\/\/.*$/, "", s); return s }
  function quoted_after(s, key,   t) {
    if (match(s, key "[ \t]+\"[^\"]*\"")) {
      t = substr(s, RSTART, RLENGTH); sub(/^[^"]*"/, "", t); sub(/"$/, "", t); return t
    }
    return ""
  }
  {
    line = $0
    sub(/^[ \t]+/, "", line)
    if (line ~ /^\/\//) next

    if (depth == 0) {
      kind = ""
      if (line ~ /^\/-/)                       kind = "skip"   # KDL slashdash: commented-out node
      else if (line ~ /^workspace[ \t]+"/)    { kind = "ws"; wsname = quoted_after(line, "workspace"); wsout = "" }
      else if (line ~ /^window-rule([ \t]|\{|$)/) { kind = "wr"; matches = ""; target = "" }
    }

    if (kind == "ws") {
      v = quoted_after(line, "open-on-output"); if (v != "") wsout = v
    } else if (kind == "wr") {
      v = quoted_after(line, "open-on-workspace"); if (v != "") target = v
      # Take the key=value properties of the match node token by token, so braces or
      # semicolons inside a quoted regex (e.g. title="x{2}") are kept intact.
      if (match(line, /(^|[ \t{;])match[ \t]+/)) {
        rest = substr(line, RSTART + RLENGTH); m = ""
        while (match(rest, /^[A-Za-z0-9_-]+=(r#"[^"]*"#|"[^"]*"|[^ \t;{}]+)/)) {
          m = m (m == "" ? "" : " ") substr(rest, 1, RLENGTH)
          rest = substr(rest, RLENGTH + 1); sub(/^[ \t]+/, "", rest)
        }
        if (m != "") matches = matches (matches == "" ? "" : ", ") m
      }
    }

    code = strip(line)
    depth += gsub(/\{/, "{", code) - gsub(/\}/, "}", code)

    if (depth == 0 && kind != "") {
      if (kind == "ws" && wsname != "") { n++; name[n] = wsname; out[n] = wsout }
      if (kind == "wr" && target != "") occ[target] = occ[target] (occ[target] == "" ? "" : " ; ") (matches == "" ? "(rule without match)" : matches)
      kind = ""
    }
  }
  END {
    free = ""; count = 0; prefixes = ""; nprefixes = 0
    for (i = 1; i <= n; i++) {
      outcount[out[i]]++
      if (out[i] != want) continue
      count++
      printf "slot %s  %s\n", name[i], (name[i] in occ ? occ[name[i]] : "(free)")
      if (!(name[i] in occ)) free = free (free == "" ? "" : " ") name[i]
      if (match(name[i], /-[0-9]+$/)) {
        p = substr(name[i], 1, RSTART - 1)
        if (!(p in seenp)) { seenp[p] = 1; nprefixes++; prefixes = prefixes (prefixes == "" ? "" : ", ") p }
      }
    }
    if (count == 0) print "slots: none on " want
    print "free-slots: " (free == "" ? "none" : free)

    pfx = prefix_arg
    if (pfx == "" && nprefixes == 1) pfx = prefixes
    if (pfx == "") {
      if (count == 0) reason = "no slots on " want " yet; rerun with a prefix argument"
      else if (nprefixes == 0) reason = "slots on " want " do not follow <prefix>-<n>; rerun with a prefix argument"
      else reason = "slots on " want " use more than one prefix (" prefixes "); rerun with one as the prefix argument"
      print "next-new-slot: ? (" reason ")"
    } else {
      max = 0
      for (i = 1; i <= n; i++) {
        if (index(name[i], pfx "-") == 1) {
          num = substr(name[i], length(pfx) + 2)
          if (num ~ /^[0-9]+$/ && num + 0 > max) max = num + 0
        }
      }
      print "next-new-slot: " pfx "-" (max + 1)
    }

    all = ""
    for (i = 1; i <= n; i++) if (!(out[i] in shown)) { shown[out[i]] = 1; all = all (all == "" ? "" : " ") (out[i] == "" ? "(no-output)" : out[i]) "=" outcount[out[i]] }
    print "all-outputs: " (all == "" ? "none" : all)
  }
' "$OVERLAY"
