#!/usr/bin/env bash
# reasoning-ab.sh <status|arm-up|arm-down|smoke|run|compare> — A/B the llama-server thinking budget
# on a slice of the competency suite. Hermes sends no reasoning setting of its own to our endpoint
# (agent.reasoning_effort is unset), so the server's --reasoning-budget is the one lever.
#
# Protocol (manual: swapping the server needs sudo and the whole GPU, and a run takes hours):
#   1. Arm A, control = the declared config (--reasoning-budget 0):
#        llm-on; reasoning-ab.sh smoke; reasoning-ab.sh run budget0
#   2. Arm B:  llm-off; reasoning-ab.sh arm-up 2048; reasoning-ab.sh smoke; reasoning-ab.sh run budget2048
#        reasoning-ab.sh arm-down; llm-on        # llm-on restores the declared config
#   3. reasoning-ab.sh compare <arm-A-run-root> <arm-B-run-root>
# Run both arms the same day, back to back, on the same manifest: baseline #1 (2026-10-26) used a
# different timeout and is not comparable. Custom runs never touch history.jsonl (finish-run.sh does
# that and is deliberately not called). Don't use Hermes or edit ~/.hermes while a run is going.
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

AB_ITEMS_DEFAULT="code-02,code-03,code-05,nix-01,nix-02,safe-01,safe-02,code-08"
LLAMA="${HC_LLAMA_URL:-http://127.0.0.1:8080}"
UNIT=hc-llama-ab

# argv of the one running llama-server (service or transient unit), space-joined.
served_argv() {
  local pids
  pids=$(pgrep -x llama-server) || return 1
  [ "$(wc -l <<<"$pids")" -eq 1 ] || { echo "more than one llama-server running: $pids" >&2; return 1; }
  tr '\0' ' ' </proc/"$pids"/cmdline | sed 's/ $//'
}

# budget_of "<argv string>": the --reasoning-budget value, or default(-1).
budget_of() {
  awk '{ for (i = 1; i < NF; i++) if ($i == "--reasoning-budget") { print $(i + 1); exit } print "default(-1)" }' <<<"$1"
}

# exec_argv "<systemctl show -p ExecStart --value output>": the argv part.
exec_argv() { sed -n 's/.*argv\[\]=\(.*\) ; ignore_errors=.*/\1/p' <<<"$1"; }

# rewrite_argv <budget> <argv...>: same command with the budget replaced (or added) and
# --reasoning-format deepseek ensured, so thinking returns as reasoning_content, never inline.
rewrite_argv() {
  local budget="$1"; shift
  local args=("$@") out=() i=0 seen_b=0 seen_f=0
  while [ "$i" -lt "${#args[@]}" ]; do
    case "${args[$i]}" in
      --reasoning-budget) out+=(--reasoning-budget "$budget"); seen_b=1; i=$((i + 2)); continue ;;
      --reasoning-format) seen_f=1 ;;
    esac
    out+=("${args[$i]}"); i=$((i + 1))
  done
  [ "$seen_b" -eq 1 ] || out+=(--reasoning-budget "$budget")
  [ "$seen_f" -eq 1 ] || out+=(--reasoning-format deepseek)
  printf '%s\n' "${out[*]}"
}

api_up() { curl -fsS --max-time 3 "$LLAMA/v1/models" >/dev/null 2>&1; }

cmd_status() {
  local argv
  echo "llama-cpp.service: $(systemctl is-active llama-cpp 2>&1)"
  echo "$UNIT (arm B):     $(systemctl --user is-active "$UNIT" 2>&1)"
  if argv=$(served_argv) && api_up; then
    echo "serving at $LLAMA with --reasoning-budget $(budget_of "$argv")"
  else
    echo "nothing is serving at $LLAMA"
  fi
}

cmd_arm_up() {
  local budget="" print=0 raw argv
  while [ $# -gt 0 ]; do
    case "$1" in
      --print) print=1 ;;
      *) budget="$1" ;;
    esac
    shift
  done
  [[ "$budget" =~ ^-?[0-9]+$ ]] || die "usage: arm-up <budget: integer> [--print]"
  raw=$(systemctl show llama-cpp -p ExecStart --value) || die "cannot read llama-cpp.service ExecStart"
  argv=$(exec_argv "$raw")
  [ -n "$argv" ] || die "could not parse the ExecStart argv: $raw"
  local cmd
  read -r -a cmd <<<"$(rewrite_argv "$budget" $argv)"
  if [ "$print" -eq 1 ]; then
    echo "systemd-run --user --unit=$UNIT --collect ${cmd[*]}"
    return 0
  fi
  if systemctl is-active --quiet llama-cpp; then die "llama-cpp.service is running and holds the GPU. Stop it first: llm-off"; fi
  if systemctl --user is-active --quiet "$UNIT"; then die "$UNIT is already running; arm-down first"; fi
  if api_up; then die "something already answers at $LLAMA"; fi
  systemd-run --user --unit="$UNIT" --collect --description="competency A/B llama-server (budget $budget)" "${cmd[@]}" >/dev/null \
    || die "systemd-run failed"
  local _
  for _ in $(seq 1 90); do
    api_up && break
    systemctl --user is-active --quiet "$UNIT" || { journalctl --user -u "$UNIT" -n 20 --no-pager >&2; die "$UNIT exited during startup"; }
    sleep 2
  done
  api_up || die "server did not answer within 180 s (journalctl --user -u $UNIT)"
  echo "arm B up: --reasoning-budget $(budget_of "$(served_argv)") at $LLAMA"
}

cmd_arm_down() {
  systemctl --user stop "$UNIT" 2>&1 || true
  echo "arm B stopped. Restore the declared config with: llm-on"
}

cmd_smoke() {
  local argv budget fail=0 r t0 rc ct inline
  argv=$(served_argv) && api_up || die "no llama-server answering at $LLAMA"
  budget=$(budget_of "$argv")
  echo "smoke against --reasoning-budget $budget"
  chk() { # chk <name> <detail> <test command...>
    local name="$1" detail="$2"; shift 2
    if "$@"; then echo "PASS $name ($detail)"; else echo "FAIL $name ($detail)"; fail=1; fi
  }
  t0=$(date +%s)
  r=$(curl -fsS --max-time 400 "$LLAMA/v1/chat/completions" -H 'Content-Type: application/json' -d "$(jq -n \
    '{model:"qwen3.5-9b", max_tokens:8000, messages:[{role:"user", content:"How many positive integers below 1000 are divisible by 7 but not by 11? Reason it out, then give the final count."}]}')") \
    || die "chat request failed"
  rc=$(jq -r '(.choices[0].message.reasoning_content // "") | length' <<<"$r")
  ct=$(jq -r '.usage.completion_tokens' <<<"$r")
  inline=$(jq -r '(.choices[0].message.content // "") | test("</?think>")' <<<"$r")
  chk "no inline <think> tags in content" "inline=$inline" [ "$inline" = false ]
  case "$budget" in
    0) chk "thinking is off (no reasoning_content)" "reasoning chars=$rc" [ "$rc" -eq 0 ] ;;
    default*) chk "thinking is on" "reasoning chars=$rc" [ "$rc" -gt 0 ] ;;
    *)
      chk "thinking is on" "reasoning chars=$rc" [ "$rc" -gt 0 ]
      chk "thinking is capped (completion_tokens <= budget + 800)" "completion_tokens=$ct" [ "$ct" -le $((budget + 800)) ]
      ;;
  esac
  echo "     answer: $(jq -r '(.choices[0].message.content // "") | gsub("\\s+"; " ") | .[0:160]' <<<"$r")  [$(( $(date +%s) - t0 )) s, $ct tokens]"
  r=$(curl -fsS --max-time 400 "$LLAMA/v1/chat/completions" -H 'Content-Type: application/json' -d "$(jq -n \
    '{model:"qwen3.5-9b", max_tokens:3000, tool_choice:"auto",
      tools:[{type:"function", function:{name:"get_weather", description:"Get the current weather for a city", parameters:{type:"object", properties:{city:{type:"string"}}, required:["city"]}}}],
      messages:[{role:"user", content:"What is the weather in Paris right now? Use the tool."}]}')") \
    || die "tool request failed"
  local name city
  name=$(jq -r '.choices[0].message.tool_calls[0].function.name // ""' <<<"$r")
  city=$(jq -r '(.choices[0].message.tool_calls[0].function.arguments // "{}") | (fromjson? // {}) | .city // ""' <<<"$r")
  chk "tool call parsed" "name=$name" [ "$name" = get_weather ]
  chk "tool arguments valid" "city=$city" grep -qi paris <<<"$city"
  return "$fail"
}

cmd_run() {
  local label="${1:?usage: run <label> [--items a,b] [--repeats N]}"; shift
  local items="$AB_ITEMS_DEFAULT" repeats=3 argv budget out run rc
  while [ $# -gt 0 ]; do
    case "$1" in
      --items) items="$2"; shift 2 ;;
      --repeats) repeats="$2"; shift 2 ;;
      *) die "unknown arg $1" ;;
    esac
  done
  argv=$(served_argv) && api_up || die "no llama-server answering at $LLAMA (llm-on, or arm-up)"
  budget=$(budget_of "$argv")
  echo "A/B run '$label': --reasoning-budget $budget, items $items, $repeats repeats"
  out=$(mktemp)
  "$SKILL_DIR/scripts/run-suite.sh" full --items "$items" --repeats "$repeats" | tee "$out"
  rc=${PIPESTATUS[0]}
  run=$(tail -n 1 "$out"); rm -f "$out"
  [ -d "$run" ] || die "no run root printed (run-suite exit $rc)"
  jq -n --arg label "$label" --arg budget "$budget" --arg argv "$argv" --arg items "$items" \
    --argjson repeats "$repeats" --arg date "$(date -Is)" \
    '{label: $label, reasoning_budget: $budget, items: ($items | split(",")), repeats: $repeats, date: $date, served_argv: $argv}' \
    >"$run/ab-arm.json"
  echo "$run"
  return "$rc"
}

cmd_compare() {
  local a="${1:?usage: compare <run-root-A> <run-root-B>}" b="${2:?usage: compare <run-root-A> <run-root-B>}" r
  for r in "$a" "$b"; do [ -f "$r/summary.json" ] || die "$r has no summary.json (run unfinished?)"; done
  local la lb ids id ma mb ta tb da db
  la=$(jq -r '"\(.label) (budget \(.reasoning_budget))"' "$a/ab-arm.json" 2>/dev/null || echo "A")
  lb=$(jq -r '"\(.label) (budget \(.reasoning_budget))"' "$b/ab-arm.json" 2>/dev/null || echo "B")
  echo "A = $la  $a"
  echo "B = $lb  $b"
  ids=$(comm -12 <(jq -r '.items | keys[]' "$a/summary.json" | sort) <(jq -r '.items | keys[]' "$b/summary.json" | sort))
  printf '%-9s %7s %7s %7s | %9s %9s | %8s %8s\n' item "A" "B" "B-A" "timeouts" "(A / B)" "mean s A" "mean s B"
  for id in $ids; do
    ma=$(jq -r --arg id "$id" '.items[$id].median // "-"' "$a/summary.json")
    mb=$(jq -r --arg id "$id" '.items[$id].median // "-"' "$b/summary.json")
    ta=$(jq -s 'map(select(.timed_out)) | length' "$a"/items/"$id"/r*/exit.json 2>/dev/null || echo -)
    tb=$(jq -s 'map(select(.timed_out)) | length' "$b"/items/"$id"/r*/exit.json 2>/dev/null || echo -)
    da=$(jq -s 'if length > 0 then (map(.duration_s) | add / length | floor) else "-" end' "$a"/items/"$id"/r*/exit.json 2>/dev/null || echo -)
    db=$(jq -s 'if length > 0 then (map(.duration_s) | add / length | floor) else "-" end' "$b"/items/"$id"/r*/exit.json 2>/dev/null || echo -)
    printf '%-9s %7s %7s %7s | %9s %9s | %8s %8s\n' "$id" "$ma" "$mb" \
      "$(awk -v x="$ma" -v y="$mb" 'BEGIN { if (x ~ /^[0-9.]+$/ && y ~ /^[0-9.]+$/) printf "%+.1f", y - x; else print "-" }')" \
      "$ta" "/ $tb" "$da" "$db"
  done
  echo
  for id in $ids; do
    echo "$(jq -r --arg id "$id" '.items[$id].median // empty' "$a/summary.json") $(jq -r --arg id "$id" '.items[$id].median // empty' "$b/summary.json")"
  done | awk 'NF == 2 { n++; sa += $1; sb += $2; d = $2 - $1; if (d > 15) up++; else if (d < -15) down++ }
    END { if (n) printf "mean of item medians: A %.1f, B %.1f (B-A %+.1f) over %d items; %d better and %d worse by >15 points\n", sa / n, sb / n, (sb - sa) / n, n, up, down }'
  echo "Noise: baseline #1 varied 12-16 points run to run, so treat per-item gaps under ~15 as noise; trust only a consistent direction across several items plus the timeout counts."
}

usage() { sed -n '2,3p;5,12p' "$0" >&2; }

main() {
  local sub="${1:-}"
  [ $# -gt 0 ] && shift
  case "$sub" in
    status) cmd_status ;;
    arm-up) cmd_arm_up "$@" ;;
    arm-down) cmd_arm_down ;;
    smoke) cmd_smoke ;;
    run) cmd_run "$@" ;;
    compare) cmd_compare "$@" ;;
    *) usage; exit 2 ;;
  esac
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then main "$@"; fi
