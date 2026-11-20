#!/usr/bin/env bash
# precheck.sh [hermes|claude] [item-id...]
# Verifies a run can start. Exit 0 = ready; 2 = llama-cpp is down (tell the user to run llm-on);
# 1 = anything else (message says what). Also pre-fetches the toolchains items verify with.
set -uo pipefail
source "$(dirname "$0")/lib.sh"

TAKER="${1:-hermes}"; shift || true
LLAMA="${HC_LLAMA_URL:-http://127.0.0.1:8080}"
problems=()
remote_info=""

for t in jq python3 rsync zstd git timeout nix claude; do
  command -v "$t" >/dev/null || problems+=("missing tool: $t")
done
if [ "$TAKER" = hermes ]; then
  command -v hermes >/dev/null || problems+=("missing tool: hermes")
  if [ -n "${HC_REMOTE_MODEL:-}" ]; then
    # Remote model: no llama-server needed. Check the key file, then (unless HC_SKIP_REMOTE_CHECK=1) ask
    # OpenRouter whether the model fits Hermes (tools, >=64K context) and whether the key works.
    kp=$(remote_key_problem)
    if [ -n "$kp" ]; then
      problems+=("$kp")
    elif [ "${HC_SKIP_REMOTE_CHECK:-0}" != 1 ]; then
      minfo=$(curl -fsS --max-time 30 https://openrouter.ai/api/v1/models 2>/dev/null \
        | jq -c --arg m "$HC_REMOTE_MODEL" '.data[] | select(.id == $m) | {ctx: .context_length, tools: ((.supported_parameters // []) | index("tools") != null)}') || minfo=""
      if [ -z "$minfo" ]; then
        problems+=("model $HC_REMOTE_MODEL is not in OpenRouter's model list (or the list could not be fetched)")
      else
        jq -e '.tools' <<<"$minfo" >/dev/null || problems+=("$HC_REMOTE_MODEL does not advertise tool support")
        jq -e '.ctx >= 65536' <<<"$minfo" >/dev/null || problems+=("$HC_REMOTE_MODEL has under 64K context, Hermes's minimum")
      fi
      kinfo=$(remote_key_info) || kinfo=""
      if [ -z "$kinfo" ]; then
        problems+=("OpenRouter rejected the saved key, or could not be reached")
      else
        remote_info="remote=$HC_REMOTE_MODEL $(jq -r '"key_limit_remaining=\(.limit_remaining // "none") free_requests_left_today=\(.free_model_daily_requests.remaining // "n/a")"' <<<"$kinfo")"
        case "$HC_REMOTE_MODEL" in
          *:free)
            if [ "${HC_ALLOW_FREE_CAP:-0}" != 1 ] && jq -e '(.free_model_daily_requests.limit // 0) < 1000' <<<"$kinfo" >/dev/null; then
              problems+=("free models are capped at $(jq -r '.free_model_daily_requests.limit // "?"' <<<"$kinfo") requests/day on this account, too few for a run (buying 10 credits lifts it to 1000; HC_ALLOW_FREE_CAP=1 overrides)")
            fi ;;
        esac
      fi
    fi
  elif ! curl -fsS --max-time 5 "$LLAMA/v1/models" >/dev/null 2>&1; then
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

# A run already in progress would share the sandbox and test home. Checked before validation, which
# writes baseline.json into the key dir that the running run hashes and guards: validating during a run
# would show up as a critical key-dir change in its repeats.
if [ -e "$WORK_DIR/.lock" ] && kill -0 "$(cat "$WORK_DIR/.lock" 2>/dev/null)" 2>/dev/null; then
  problems+=("another run is in progress (pid $(cat "$WORK_DIR/.lock"))")
fi

# Items drift when the repo or the world changes under them (code-08 patches the committed
# modules/audio.nix; live items read today's network). Re-validating answer keys catches that.
if [ ${#problems[@]} -eq 0 ] && [ "${HC_SKIP_VALIDATE:-0}" != 1 ]; then
  if ! vout=$("$SKILL_DIR/scripts/validate-items.sh" "${ids[@]}" 2>&1); then
    problems+=("item validation failed:")
    while IFS= read -r l; do problems+=("  $l"); done < <(grep '^FAIL' <<<"$vout")
  fi
fi

if [ ${#problems[@]} -gt 0 ]; then
  printf 'not ready:\n'; printf '  - %s\n' "${problems[@]}"; exit 1
fi
echo "ready: taker=$TAKER items=${#ids[@]}${remote_info:+ $remote_info}"
