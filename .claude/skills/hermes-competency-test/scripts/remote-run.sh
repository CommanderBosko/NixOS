#!/usr/bin/env bash
# remote-run.sh <save-key|check|run|compare> — run the competency suite against an OpenRouter model
# instead of the local Qwen, and line the result up against the local baseline.
#
#   remote-run.sh save-key                 hidden-prompt capture of the OpenRouter key into a mode-600 file (needs a terminal)
#   remote-run.sh check                    what OpenRouter says about the saved key: limits, spend, free-model cap (never prints the key)
#   remote-run.sh run <model-id> [--items a,b] [--repeats N]
#                                          the manifest's quick slice x 3 repeats as a custom run (never touches history.jsonl)
#   remote-run.sh compare <run-root>...    per-item medians next to the local baseline
#
# No llama-server is needed (no llm-on). The key reaches Hermes only through the throwaway test home's
# .env, written by run-item.sh after each reset; run prints a leak scan of the run directory at the end.
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

cmd_save_key() {
  [ -t 0 ] || die "save-key needs a terminal: the key is read with echo off, so run it in your own terminal (not through a pipe or a ! command)"
  local k
  read -rsp "OpenRouter API key (input hidden): " k; echo
  [[ "$k" =~ ^sk-or-[A-Za-z0-9_-]{16,}$ ]] || { unset k; die "that doesn't look like an OpenRouter key (expected sk-or-...); nothing was saved"; }
  mkdir -p "$(dirname "$REMOTE_KEY_FILE")"
  ( umask 077; printf '%s\n' "$k" >"$REMOTE_KEY_FILE" )
  chmod 600 "$REMOTE_KEY_FILE"
  unset k
  echo "saved to $REMOTE_KEY_FILE (mode 600)"
  cmd_check
}

cmd_check() {
  local p info
  p=$(remote_key_problem); [ -z "$p" ] || die "$p"
  info=$(remote_key_info) && [ -n "$info" ] || die "OpenRouter rejected the key, or could not be reached"
  jq -r '"credit limit on this key: \(.limit // "none") (remaining \(.limit_remaining // "n/a"))\nspent so far (all time): $\(.usage)\nfree-model requests today: \(.free_model_daily_requests.used // "n/a") used of \(.free_model_daily_requests.limit // "n/a")"' <<<"$info"
}

key_usage() { remote_key_info 2>/dev/null | jq -r '.usage // empty'; }

cmd_run() {
  local model="${1:?usage: run <openrouter-model-id> [--items a,b] [--repeats N]}"; shift
  local items repeats=3 out run rc before after spent hits key
  items=$(jq -r '.quick | join(",")' "$MANIFEST")
  while [ $# -gt 0 ]; do
    case "$1" in
      --items) items="$2"; shift 2 ;;
      --repeats) repeats="$2"; shift 2 ;;
      *) die "unknown arg $1" ;;
    esac
  done
  export HC_REMOTE_MODEL="$model"
  before=$(key_usage)
  echo "remote run: $model, items $items, $repeats repeats"
  out=$(mktemp)
  "$SKILL_DIR/scripts/run-suite.sh" full --items "$items" --repeats "$repeats" | tee "$out"
  rc=${PIPESTATUS[0]}
  run=$(tail -n 1 "$out"); rm -f "$out"
  [ -d "$run" ] || die "no run root printed (run-suite exit $rc)"
  after=$(key_usage)
  spent=$(awk -v a="${after:-}" -v b="${before:-}" 'BEGIN { if (a != "" && b != "") printf "%.4f", a - b; else print "" }')
  jq -n --arg model "$model" --arg items "$items" --argjson repeats "$repeats" --arg date "$(date -Is)" --arg spent "$spent" \
    '{model: $model, items: ($items | split(",")), repeats: $repeats, date: $date, spent_usd: (if $spent == "" then null else ($spent | tonumber) end)}' \
    >"$run/remote-arm.json"
  # Leak scan: the key must not appear anywhere in the run directory. The pattern comes from a file,
  # so the key never lands in a process's argv.
  key=$(tr -d '[:space:]' <"$REMOTE_KEY_FILE")
  hits=$(grep -rlF -f <(printf '%s\n' "$key") "$run" 2>/dev/null || true)
  unset key
  if [ -n "$hits" ]; then
    echo "WARNING: the OpenRouter key string appears in these run files (rotate the key and scrub them):"
    sed 's/^/  /' <<<"$hits"
  else
    echo "key leak scan: clean"
  fi
  echo "spend this run: ${spent:-unknown}"
  echo "$run"
  return "$rc"
}

cmd_compare() {
  local base="${HC_BASELINE:-$RUNS_DIR/20261026-222043-full-hermes}"
  [ $# -gt 0 ] || die "usage: compare <run-root>... (the local baseline is always column 0)"
  local runs=("$base" "$@") labels=() r i ids id line cell m t mean
  for r in "${runs[@]}"; do
    [ -f "$r/summary.json" ] || die "$r has no summary.json (run unfinished?)"
    if [ "${#labels[@]}" -eq 0 ]; then labels+=("local baseline")
    else labels+=("$(jq -r '.model // "?"' "$r/remote-arm.json" 2>/dev/null || basename "$r")"); fi
  done
  for i in "${!runs[@]}"; do
    echo "[$i] ${labels[$i]}  ${runs[$i]}$(jq -r '"  (spent $\(.spent_usd // "?"))"' "${runs[$i]}/remote-arm.json" 2>/dev/null)"
  done
  ids=$(jq -r '.items | keys[]' "${runs[-1]}/summary.json")
  line=$(printf '%-9s' item); for i in "${!runs[@]}"; do line+=$(printf ' %-10s' "[$i]"); done; echo "$line"
  for id in $ids; do
    line=$(printf '%-9s' "$id")
    for r in "${runs[@]}"; do
      m=$(jq -r --arg id "$id" '.items[$id].median // "-"' "$r/summary.json")
      t=$(jq -s 'map(select(.timed_out)) | length' "$r"/items/"$id"/r*/exit.json 2>/dev/null | tail -n 1)
      cell="$m"; [ "${t:-0}" -gt 0 ] && cell="$m (t$t)"
      line+=$(printf ' %-10s' "$cell")
    done
    echo "$line"
  done
  line=$(printf '%-9s' mean)
  for r in "${runs[@]}"; do
    mean=$(for id in $ids; do jq -r --arg id "$id" '.items[$id].median // empty' "$r/summary.json"; done \
      | awk '{ s += $1; n++ } END { if (n) printf "%.1f", s / n; else print "-" }')
    line+=$(printf ' %-10s' "$mean")
  done
  echo "$line"
  echo "(tN = N repeats hit the item timeout. The baseline ran all 31 items with a 900 s timeout; only the items above are compared. Run-to-run noise was 12-16 points, so trust a consistent direction across several items, not one gap.)"
}

main() {
  local sub="${1:-}"
  [ $# -gt 0 ] && shift
  case "$sub" in
    save-key) cmd_save_key ;;
    check) cmd_check ;;
    run) cmd_run "$@" ;;
    compare) cmd_compare "$@" ;;
    *) sed -n '2,10p' "$0" >&2; exit 2 ;;
  esac
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then main "$@"; fi
