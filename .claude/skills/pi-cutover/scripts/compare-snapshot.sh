#!/usr/bin/env bash
#
# compare-snapshot.sh - compare the snapshot JSON with the live JSON of the
# restored service WITHOUT printing any values.
#
# Both documents are canonicalized with jq -S (sorted keys). The comparison is
# per top-level key and is a deep equality of the sub-documents, so a changed
# value is a DIFF even when the counts agree. Output is one row per key:
#     key  snapshot-count  live-count  MATCH|DIFF|IGNORED
# where count = array length, object key count, 0 for null, 1 for any other
# scalar, and "-" when that side lacks the key. DIFF rows add a short sha256
# prefix per side. Only key names, counts and sha256 prefixes are ever printed.
# A document that is not a JSON object is compared as one row named (root).
#
# Usage:
#   compare-snapshot.sh --snapshot FILE (--url URL [--via SSH_TARGET] | --live-file FILE
#                       | --key-url KEY=URL [--key-url KEY=URL]... [--via SSH_TARGET])
#                       [--ignore-key K]...
#
#   --snapshot FILE   the JSON file from the verified snapshot
#   --url URL         fetch the live JSON with curl (http/https)
#   --via SSH_TARGET  run that curl ON the Pi over ssh (BatchMode), so a
#                     127.0.0.1 URL works, e.g. bosko@100.99.52.59
#   --live-file FILE  use live JSON already saved to a file (an API that needs
#                     a login can be saved with its own skill; keep the file
#                     private and out of the repo)
#   --key-url KEY=URL for an app whose API serves each collection on its own
#                     endpoint (FamDash: /meals, /shopping, /notes): compare ONLY
#                     the snapshot's top-level KEY against the JSON at URL.
#                     Repeatable; keys you do not list are not compared. Combine
#                     with --via to run the curls on the Pi.
#   --ignore-key K    leave this top-level key out (timestamps, counters that
#                     legitimately move); repeatable
#   -h, --help        this text
#
# Exit codes: 0 every compared key matches, 1 at least one DIFF, 2 usage error
# or an input that is missing / not valid JSON.

set -euo pipefail
umask 077

PROG="compare-snapshot.sh"
usage() {
  sed -n '/^# Usage:/,/^# Exit codes/p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}
usage_die() { echo "ERROR: $*" >&2; echo "Try: bash $PROG --help" >&2; exit 2; }

SNAP="" URL="" VIA="" LIVE="" IGNORE=() KEYURLS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --snapshot) [ $# -ge 2 ] || usage_die "--snapshot needs a value"; SNAP="$2"; shift 2 ;;
    --url) [ $# -ge 2 ] || usage_die "--url needs a value"; URL="$2"; shift 2 ;;
    --via) [ $# -ge 2 ] || usage_die "--via needs a value"; VIA="$2"; shift 2 ;;
    --live-file) [ $# -ge 2 ] || usage_die "--live-file needs a value"; LIVE="$2"; shift 2 ;;
    --key-url) [ $# -ge 2 ] || usage_die "--key-url needs a value"; KEYURLS+=("$2"); shift 2 ;;
    --ignore-key) [ $# -ge 2 ] || usage_die "--ignore-key needs a value"; IGNORE+=("$2"); shift 2 ;;
    -h | --help) usage; exit 0 ;;
    *) usage_die "unknown argument: $1" ;;
  esac
done

[ -n "$SNAP" ] || usage_die "--snapshot is required"
modes=0
if [ -n "$URL" ]; then modes=$((modes + 1)); fi
if [ -n "$LIVE" ]; then modes=$((modes + 1)); fi
if [ "${#KEYURLS[@]}" -gt 0 ]; then modes=$((modes + 1)); fi
[ "$modes" -ge 1 ] || usage_die "give the live side: --url URL, --key-url KEY=URL or --live-file FILE"
[ "$modes" -eq 1 ] || usage_die "--url, --key-url and --live-file are alternatives"
[ -z "$VIA" ] || [ -n "$URL" ] || [ "${#KEYURLS[@]}" -gt 0 ] || usage_die "--via only applies to --url / --key-url"
if [ "${#KEYURLS[@]}" -gt 0 ]; then
  for kv in "${KEYURLS[@]}"; do
    case "$kv" in *=*) ;; *) usage_die "--key-url wants KEY=URL, got: $kv" ;; esac
    [ -n "${kv%%=*}" ] || usage_die "--key-url has an empty KEY: $kv"
    case "${kv#*=}" in http://* | https://*) ;; *) usage_die "--key-url URL must start with http:// or https://: $kv" ;; esac
    case "${kv#*=}" in *[[:space:]]*) usage_die "--key-url URL must not contain whitespace: $kv" ;; esac
  done
fi
if [ -n "$URL" ]; then
  case "$URL" in http://* | https://*) ;; *) usage_die "--url must start with http:// or https://" ;; esac
  case "$URL" in *[[:space:]]*) usage_die "--url must not contain whitespace" ;; esac
fi
if [ -n "$VIA" ]; then
  case "$VIA" in -* | *[[:space:]]*) usage_die "--via must look like user@host" ;; esac
fi
[ -r "$SNAP" ] || usage_die "snapshot file is not readable: $SNAP"
[ -z "$LIVE" ] || [ -r "$LIVE" ] || usage_die "live file is not readable: $LIVE"

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

# fetch_json URL OUT: curl the URL (on the Pi over ssh with --via) into OUT.
fetch_json() {
  local url="$1" out="$2" remote_cmd
  if [ -n "$VIA" ]; then
    remote_cmd="curl -sS -f -m 20 $(printf '%q' "$url")"
    ssh -o BatchMode=yes -o ConnectTimeout=10 "$VIA" "$remote_cmd" >"$out" 2>"$TMP/fetch.err" ||
      { echo "ERROR: could not fetch the live JSON via $VIA: $(head -n1 "$TMP/fetch.err")" >&2; exit 2; }
  else
    curl -sS -f -m 20 "$url" >"$out" 2>"$TMP/fetch.err" ||
      { echo "ERROR: could not fetch the live JSON: $(head -n1 "$TMP/fetch.err")" >&2; exit 2; }
  fi
}

RESTRICT=""
if [ -n "$URL" ]; then
  fetch_json "$URL" "$TMP/live.raw"
  LIVE="$TMP/live.raw"
elif [ "${#KEYURLS[@]}" -gt 0 ]; then
  # Build a live document {KEY: <json at URL>, ...} and remember which keys to
  # compare, so the snapshot is cut down to the same keys below.
  echo '{}' >"$TMP/live.raw"
  RESTRICT='[]'
  i=0
  for kv in "${KEYURLS[@]}"; do
    k="${kv%%=*}"
    fetch_json "${kv#*=}" "$TMP/key-$i.raw"
    jq -e . "$TMP/key-$i.raw" >/dev/null 2>&1 || usage_die "the live JSON for key '$k' is not valid JSON"
    jq --arg k "$k" --slurpfile v "$TMP/key-$i.raw" '. + {($k): $v[0]}' "$TMP/live.raw" >"$TMP/live.next"
    mv "$TMP/live.next" "$TMP/live.raw"
    RESTRICT="$(jq -c --arg k "$k" '. + [$k]' <<<"$RESTRICT")"
    i=$((i + 1))
  done
  LIVE="$TMP/live.raw"
fi

jq -S . "$SNAP" >"$TMP/snap.json" 2>/dev/null || usage_die "the snapshot file is not valid JSON"
if [ -n "$RESTRICT" ]; then
  jq -S --argjson ks "$RESTRICT" 'if type == "object" then with_entries(select(.key as $k | $ks | index($k))) else error("not an object") end' \
    "$TMP/snap.json" >"$TMP/snap.restricted" 2>/dev/null || usage_die "--key-url needs a snapshot that is a JSON object"
  mv "$TMP/snap.restricted" "$TMP/snap.json"
fi
jq -S . "$LIVE" >"$TMP/live.json" 2>/dev/null || usage_die "the live JSON is not valid JSON"

ignore_json='[]'
if [ "${#IGNORE[@]}" -gt 0 ]; then
  ignore_json="$(printf '%s\n' "${IGNORE[@]}" | jq -R . | jq -s -c .)"
fi

# one TSV row per top-level key: key, snapshot count, live count, verdict
rows="$(jq -n -r --slurpfile s "$TMP/snap.json" --slurpfile l "$TMP/live.json" --argjson ign "$ignore_json" '
  def cnt: if type == "array" or type == "object" then length elif type == "null" then 0 else 1 end;
  def nm: if . == "" then "(empty)" else . end;
  $s[0] as $S | $l[0] as $L
  | if ($S | type) == "object" and ($L | type) == "object" then
      (($S | keys) + ($L | keys) | unique)[] as $k
      | if ($ign | index($k)) != null then [($k | nm), "-", "-", "IGNORED"]
        else [($k | nm),
              (if $S | has($k) then ($S[$k] | cnt | tostring) else "-" end),
              (if $L | has($k) then ($L[$k] | cnt | tostring) else "-" end),
              (if ($S | has($k)) and ($L | has($k)) and $S[$k] == $L[$k] then "MATCH" else "DIFF" end)]
        end
    else
      ["(root)", ($S | cnt | tostring), ($L | cnt | tostring), (if $S == $L then "MATCH" else "DIFF" end)]
    end
  | @tsv')"

short() { # short sha256 prefix of the canonical form of key $2 (or the root) of file $1
  if [ -n "$2" ]; then
    jq -S -c --arg k "$2" 'if has($k) then .[$k] else "<absent>" end' "$1" | sha256sum | cut -c1-8
  else
    jq -S -c . "$1" | sha256sum | cut -c1-8
  fi
}

total=0 diffs=0 ignored=0
printf '%-32s %10s %10s  %s\n' key snapshot live verdict
while IFS=$'\t' read -r key sc lc verdict; do
  [ -n "$verdict" ] || continue
  total=$((total + 1))
  case "$verdict" in DIFF) diffs=$((diffs + 1)) ;; IGNORED) ignored=$((ignored + 1)); total=$((total - 1)) ;; esac
  extra=""
  if [ "$verdict" = DIFF ]; then
    if [ "$key" = "(root)" ]; then rk=""; else rk="$key"; fi
    # keys that were renamed for display (empty) have no hash line; the common case is a plain key
    if [ "$key" != "(empty)" ]; then extra="  snapshot #$(short "$TMP/snap.json" "$rk") live #$(short "$TMP/live.json" "$rk")"; fi
  fi
  printf '%-32s %10s %10s  %s%s\n' "${key:0:32}" "$sc" "$lc" "$verdict" "$extra"
done <<<"$rows"

if [ "$total" -eq 0 ]; then
  echo "VERDICT: nothing to compare (no keys outside --ignore-key)"
  exit 2
fi
if [ "$diffs" -gt 0 ]; then
  echo "VERDICT: DIFF ($diffs of $total key(s) differ, $ignored ignored)"
  exit 1
fi
if [ "$ignored" -eq 0 ]; then
  echo "VERDICT: MATCH ($total key(s) compared; canonical sha256 snapshot #$(short "$TMP/snap.json" "") live #$(short "$TMP/live.json" ""))"
else
  echo "VERDICT: MATCH ($total key(s) compared, $ignored ignored)"
fi
