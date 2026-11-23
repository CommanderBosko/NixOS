# Remote-model runs (OpenRouter, manual, only when asked)

Tests whether a hosted model beats the local Qwen3.5-9B on the same items. No llama-server is needed, so no `llm-on`. Setting `HC_REMOTE_MODEL=<model-id>` makes `precheck.sh`, `prepare-run.sh` and `run-item.sh` rewrite the snapshot's `model:` block to `provider: openrouter` and write the key into the throwaway test home's `.env` after each reset. `remote-run.sh` sets it for you.

1. Key (once): in your own terminal, `<skill-dir>/scripts/remote-run.sh save-key`. It reads the key with echo off into `~/.local/share/hermes-competency/openrouter.key` (mode 600). Over ssh from another host: `ssh -t bosko@gaming <skill-dir>/scripts/remote-run.sh save-key`. Set a per-key credit limit in OpenRouter's key settings first.
2. `<skill-dir>/scripts/remote-run.sh check`: limits, spend and the free-model cap for the saved key.
3. `<skill-dir>/scripts/remote-run.sh run <model-id>`: the manifest's `quick` slice × 3 repeats as a **custom** run; precheck checks the model lists tools and ≥64K context and the key works. It prints the spend and a key-leak scan of the run directory at the end. One run at a time (the work dir is shared).
4. `<skill-dir>/scripts/remote-run.sh compare <run-root>...`: per-item medians and timeout counts next to baseline #1.

Gotchas: custom runs never go to `history.jsonl`, so don't call `finish-run.sh` on them. Never put the key in a `!` command or paste it into chat; both echo into the transcript. Free (`:free`) models are capped at 20 requests/min and 50 requests/day (1,000/day once 10 credits have been bought); precheck refuses a free model while the cap is under 1,000 unless `HC_ALLOW_FREE_CAP=1`. The grader is still `claude -p` Sonnet, so grading uses Claude tokens, not OpenRouter's.
