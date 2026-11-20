#!/usr/bin/env bash
# Tests for scripts/reasoning-ab.sh: the pure helpers and compare. No model time, no llama-server, no sudo.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=../scripts/reasoning-ab.sh
source "$HERE/../scripts/reasoning-ab.sh"
set +e
pass=0 fail=0
eq() { if [ "$2" = "$3" ]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL $1: expected [$2] got [$3]"; fi; }
has() { if grep -qF -- "$2" <<<"$3"; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL $1: missing [$2] in:"; echo "$3"; fi; }

eq "budget_of explicit 0" 0 "$(budget_of '/x/llama-server --port 8080 --reasoning-budget 0 --jinja')"
eq "budget_of 2048" 2048 "$(budget_of '/x/llama-server --reasoning-budget 2048')"
eq "budget_of absent" 'default(-1)' "$(budget_of '/x/llama-server --port 8080')"

raw='{ path=/n/llama-server ; argv[]=/n/llama-server --ctx-size 65536 --reasoning-budget 0 ; ignore_errors=no ; start_time=[n/a] ; }'
eq "exec_argv" '/n/llama-server --ctx-size 65536 --reasoning-budget 0' "$(exec_argv "$raw")"

eq "rewrite replaces budget, adds format" \
  '/n/llama-server --ctx-size 65536 --reasoning-budget 2048 --reasoning-format deepseek' \
  "$(rewrite_argv 2048 /n/llama-server --ctx-size 65536 --reasoning-budget 0)"
eq "rewrite appends a missing budget" \
  '/n/llama-server --port 1 --reasoning-budget 512 --reasoning-format deepseek' \
  "$(rewrite_argv 512 /n/llama-server --port 1)"
eq "rewrite keeps an existing format" \
  '/n/llama-server --reasoning-format none --reasoning-budget 7' \
  "$(rewrite_argv 7 /n/llama-server --reasoning-format none --reasoning-budget 0)"

tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
mk() { # mk <dir> <label> <budget> <code-02 median> <nix-01 median> <code-02 timed_out: true|false>
  mkdir -p "$1/items/code-02/r1" "$1/items/nix-01/r1"
  jq -n --argjson a "$4" --argjson b "$5" '{items: {"code-02": {median: $a}, "nix-01": {median: $b}}}' >"$1/summary.json"
  jq -n --arg l "$2" --arg b "$3" '{label: $l, reasoning_budget: $b}' >"$1/ab-arm.json"
  jq -n --argjson t "$6" '{exit_code: 0, timed_out: $t, duration_s: 100}' >"$1/items/code-02/r1/exit.json"
  echo '{"exit_code":0,"timed_out":false,"duration_s":50}' >"$1/items/nix-01/r1/exit.json"
}
mk "$tmp/a" budget0 0 40 50 true
mk "$tmp/b" budget2048 2048 70 45 false
out=$(cmd_compare "$tmp/a" "$tmp/b")
has "compare labels A" "A = budget0 (budget 0)" "$out"
has "compare labels B" "B = budget2048 (budget 2048)" "$out"
has "compare code-02 delta" "+30.0" "$out"
has "compare nix-01 delta" "-5.0" "$out"
has "compare summary" "A 45.0, B 57.5 (B-A +12.5) over 2 items; 1 better and 0 worse" "$out"
has "compare timeouts" "code-02" "$(grep code-02 <<<"$out" | grep -E ' 1 +/ 0')"

echo "passed $pass, failed $fail"
[ "$fail" -eq 0 ]
