#!/usr/bin/env bash
# precheck.sh [hermes|claude] [item-id...]
# Verifies a run can start. Exit 0 = ready; 2 = llama-cpp is down (tell the user to run llm-on);
# 1 = anything else (message says what). Also pre-fetches the toolchains items verify with.
set -uo pipefail
source "$(dirname "$0")/lib.sh"

TAKER="${1:-hermes}"; shift || true
LLAMA="${HC_LLAMA_URL:-http://127.0.0.1:8080}"
problems=()

for t in jq python3 rsync zstd git timeout nix claude; do
  command -v "$t" >/dev/null || problems+=("missing tool: $t")
done
if [ "$TAKER" = hermes ]; then
  command -v hermes >/dev/null || problems+=("missing tool: hermes")
  if ! curl -fsS --max-time 5 "$LLAMA/v1/models" >/dev/null 2>&1; then
    echo "llama-cpp is not answering at $LLAMA — run llm-on first, then re-run."
    exit 2
  fi
  [ -d "$LIVE_HOME" ] || problems+=("no live Hermes home at $LIVE_HOME")
fi
[ -f "$MANIFEST" ] && jq -e . "$MANIFEST" >/dev/null 2>&1 || problems+=("manifest.json missing or invalid")
[ -d "$KEYS_DIR" ] || problems+=("private key dir $KEYS_DIR missing (rubrics/checks live there, not in git)")

ids=("$@")
[ ${#ids[@]} -gt 0 ] || mapfile -t ids < <(jq -r '.items[]' "$MANIFEST" 2>/dev/null)
for id in "${ids[@]}"; do
  [ -f "$SKILL_DIR/items/$id/prompt.md" ] || problems+=("$id: no prompt.md")
  [ -f "$KEYS_DIR/$id/rubric.json" ] || problems+=("$id: no private rubric.json")
done

# Toolchains used by item checks and by the taker's own verification (fetched once, then cached).
nix build --no-link nixpkgs#typescript nixpkgs#shellcheck nixpkgs#bubblewrap >/dev/null 2>&1 \
  || problems+=("could not fetch typescript/shellcheck/bubblewrap via nix")

# Items drift when the repo or the world changes under them (code-08 patches the committed
# modules/audio.nix; live items read today's network). Re-validating answer keys catches that.
if [ ${#problems[@]} -eq 0 ] && [ "${HC_SKIP_VALIDATE:-0}" != 1 ]; then
  if ! vout=$("$SKILL_DIR/scripts/validate-items.sh" "${ids[@]}" 2>&1); then
    problems+=("item validation failed:")
    while IFS= read -r l; do problems+=("  $l"); done < <(grep '^FAIL' <<<"$vout")
  fi
fi

# A run already in progress would share the sandbox and test home.
if [ -e "$WORK_DIR/.lock" ] && kill -0 "$(cat "$WORK_DIR/.lock" 2>/dev/null)" 2>/dev/null; then
  problems+=("another run is in progress (pid $(cat "$WORK_DIR/.lock"))")
fi

if [ ${#problems[@]} -gt 0 ]; then
  printf 'not ready:\n'; printf '  - %s\n' "${problems[@]}"; exit 1
fi
echo "ready: taker=$TAKER items=${#ids[@]}"
