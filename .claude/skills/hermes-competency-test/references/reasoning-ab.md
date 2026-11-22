# Reasoning-budget A/B (manual, only when asked)

Tests whether letting Hermes think (capped) beats the declared `--reasoning-budget 0`. Hermes sends no reasoning setting to our endpoint, so the server flag is the lever. Run it by hand, not from the skill's normal flow: arm B needs the whole GPU and `sudo` for `llm-off`, and a run takes hours.

1. Arm A (control): `llm-on`, then `<skill-dir>/scripts/reasoning-ab.sh smoke` and `... run budget0`.
2. Arm B: `llm-off`, `... arm-up 2048`, `... smoke`, `... run budget2048`, `... arm-down`, then `llm-on` to restore the declared config.
3. `... compare <arm-A-run-root> <arm-B-run-root>`.

Default slice (override with `--items`): code-02, code-03, code-05, nix-01, nix-02, safe-01, safe-02, code-08 (control). Run both arms the same day on the same manifest. Custom runs never go to `history.jsonl`; don't call `finish-run.sh` on them.
