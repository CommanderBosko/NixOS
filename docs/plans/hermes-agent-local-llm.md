# Plan: Hermes Agent on gaming with a local Qwen3.5-9B (attempt 2)

Status: **PLANNED, not started**. Written 2026-10-15. The research behind it is the memory
`reference_hermes_agent_8gb_research.md`.

## Goal

Run NousResearch's Hermes Agent on `gaming` against a local model on the RTX 3070 (8 GB). It has to
meet Hermes' hard **64K-context minimum** and make tool calls reliably, without permanently taking
the GPU away from gaming.

## Why the first attempt failed (2026-05-26 → 05-27, removed in `25922c2`)

1. **The KV cache didn't fit.** At 64K context, the KV cache (the per-token memory the model keeps
   for its context) needs about 8 GiB for llama3.1:8b and about 10 GiB for mistral-nemo:12b. That
   is before the weights are loaded, so none of the models we tried could fit.
2. **Ollama ignored the context size.** The old config passed `model.ollama_num_ctx = 65536` with
   each request, but Ollama's OpenAI-compatible `/v1` endpoint silently ignores `num_ctx` (Ollama
   issue #11409, still open). Models loaded at Ollama's default context, which likely explains the
   "empty responses" fix (`fdef50f`) and the num_ctx churn after it.
3. **The desktop already uses VRAM, and the budget never accounted for it.** On 2026-10-15, with
   Zen, Vesktop, Steam and Deezer open, the desktop was using **about 1.5 GB**. That leaves
   **about 6.5 GB** for the model.

## What's different now

- **Qwen3.5-9B** keeps about 32 KiB of KV cache per token (measured on an RTX 3070), roughly 4×
  less than llama3.1:8b. It also scores about 85% on TAU2 for tool calling.
- **Switching from Ollama to llama.cpp** fixes problem 2: `-c` sets the context on the server, so
  there is no per-request `num_ctx` to lose. It also avoids Ollama's `qwen3.5:9b-q4_K_M`
  (6.6 GB), which bundles the vision projector. A text-only GGUF is smaller.
- nixpkgs (our lock): `llama-cpp-cuda` exists, and `services.llama-cpp` takes arbitrary
  `llama-server` flags through `settings`.
- The hermes-agent flake still exports `nixosModules`, with `settings`, `environmentFiles`,
  `addToSystemPackages` and `extraPackages`. v0.22 lazy-loads about 19 tools and trims about 2.1k
  tokens from the fixed prompt, so each turn uses less context.

## VRAM budget (estimates, to be verified in step 6)

| Item | Size |
|---|---|
| Desktop baseline (measured 2026-10-15) | ~1.5 GB |
| Qwen3.5-9B **IQ4_XS** weights, text-only | ~5.4 GB |
| KV cache @ 64K: f16 / **q8_0** / q4_0 | ~2.0 / **~1.0** / ~0.5 GiB |
| Compute buffers | ~0.3–0.5 GB |
| **Total with q8_0 KV** | **~7.2–7.4 GB of 7.84 GB usable** |

This is tight but should fit. If it doesn't, the fallbacks are, in order:

1. q4_0 KV cache
2. Close the browser or Discord while using it
3. Offload 1–3 layers to CPU (`-ngl`), which slows it down
4. Qwen3.5-4B, which has weaker tool calling

## Decisions to confirm before starting (via AskUserQuestion)

1. **Runtime:** llama.cpp via `services.llama-cpp` *(recommended)*, or Ollama again (needs
   `OLLAMA_CONTEXT_LENGTH` set server-side, and the 6.6 GB tag probably won't fit next to the
   desktop).
2. **Gaming coexistence:** keep the LLM **on-demand** *(recommended)*. `llama-cpp.service` would
   not start at boot; `llm-on` / `llm-off` aliases would start and stop it so games get the whole
   GPU. The alternative is always-on, and remembering to stop it before gaming.
3. **Hermes usage:** CLI only, or also the always-on gateway service (messaging bots)? Gateway
   requests fail while the LLM is off.
4. **Model weights:** pinned `pkgs.fetchurl` of the GGUF into the store *(recommended: declarative,
   hash-pinned, no network needed at service start)*, or `-hf` download at runtime into a state
   dir.
5. **Exact GGUF:** base Qwen3.5-9B-Instruct IQ4_XS from bartowski or unsloth *(recommended)*, or
   the Qwopus fine-tune from the 8 GB field report (one author's build).
6. **Qwen thinking mode:** off by default (`--reasoning off` or a template kwarg) to save context,
   or on? This can be decided by testing in step 7.

## Implementation steps

**0. Prep (independent; run in parallel):**
- Fetch the chosen GGUF's URL and sha256 from Hugging Face.
- Check whether `llama-cpp-cuda` is in a binary cache. If not, a local CUDA build takes about
  20–40 minutes; plan for that.
- Confirm that the `llama-server` in our lock supports the Qwen3.5 architecture, and check the
  exact flag names: `--cache-type-k/v`, `-fa`, `--jinja`, `-np`, `--reasoning`.
- Read hermes-agent's `nix/moduleCommon.nix` for the current `settings.model.*` keys.

**1. `flake.nix`** (coupled with step 2, so do them serially):
- Re-add the input `hermes-agent.url = "github:NousResearch/hermes-agent";`. Keep the old setup:
  no `follows`, because upstream pins its own nixpkgs.
- Add `hermes-agent` to the `outputs` args.
- In `gamingModules`, add `"${self}/hosts/gaming/hermes-agent.nix"` and
  `hermes-agent.nixosModules.default`.

**2. `hosts/gaming/hermes-agent.nix`** (new; start from `git show 25922c2^:hosts/gaming/hermes-agent.nix`):
- `services.llama-cpp`: `enable`, `package = pkgs.llama-cpp-cuda`, `host = "127.0.0.1"`,
  `port = 8080`, and `settings` with:
  - model = the fetched GGUF
  - `ctx-size = 65536`
  - **`parallel = 1`**. Multiple slots split the context; four slots would give 16K each, which is
    under the gate.
  - `n-gpu-layers = 99`
  - `flash-attn = on`
  - `cache-type-k` and `cache-type-v` = `q8_0`
  - `jinja = true`, which tool calls need
- On-demand: `systemd.services.llama-cpp.wantedBy = lib.mkForce [ ];`
- `services.hermes-agent.settings.model`:
  - `provider = "custom"`
  - `base_url = "http://127.0.0.1:8080/v1"`
  - dummy `api_key = "local"`
  - `api_mode = "chat_completions"`
  - `context_length = 65536`
  - remove `ollama_num_ctx`
- Keep `addToSystemPackages = true` and `users.users.bosko.extraGroups = [ "hermes" ]`. This is
  the May fix for the `PermissionError` on `/var/lib/hermes`.
- Drop `hardware.nvidia-container-toolkit.enable`. It was only needed for Ollama, and llama.cpp
  doesn't use containers.
- Comment block: record the VRAM budget and the reason for each flag, especially `parallel = 1`
  and the KV cache type.

**3. Aliases:** add `llm-on`, `llm-off` and `llm-status` (systemctl start/stop/status for
`llama-cpp`). Put them in gaming's `environment.nix`, or wherever gaming-only aliases live. Check
before adding.

**4. Docs:** update the `README.md` feature bullet and `project-state.md` (decision entry), and add
a memory note.

## Verification plan

| # | Check | How | Pass criteria |
|---|---|---|---|
| 1 | Config evaluates | `nixos-dry-run` skill on gaming, then `deep-eval-check` (flake input change) | clean eval, all 4 hosts |
| 2 | Builds and activates | `nh os switch` on gaming (or boot + reboot) | no failed units |
| 3 | Server starts | `llm-on`, then the `verify-service` skill for `llama-cpp` | active; `curl 127.0.0.1:8080/props` shows `n_ctx` 65536 and 1 slot |
| 4 | Fits in VRAM with desktop open | `nvidia-smi` with the normal desktop apps open | model fully on GPU, total < ~7.7 GB, no OOM in `journalctl -u llama-cpp` |
| 5 | Passes the 64K gate | start `hermes` CLI and `verify-service hermes-agent` (if the gateway is enabled) | no "below the minimum 64,000" error |
| 6 | Tool calling works | 3 tasks: read a repo file, run a shell command, fetch a URL | each makes a real tool call with a correct result (tool_turns > 0) |
| 7 | Long context holds | a session pushed past ~50K tokens | no crash or OOM; record tok/s (expect ~8–15 at the high end) |
| 8 | Coexists with gaming | `llm-off`, then `nvidia-smi` | VRAM back to desktop baseline |

The work is done when 1–8 all pass. If check 4 fails, apply the fallbacks from the budget section
in order, and re-run 4–7 after each one.

## Parallelization

- Step 0's four checks are independent of each other and can run in parallel.
- Steps 1 and 2 are coupled (a new module plus the flake line that imports it), so they run
  serially.
- Step 3 (aliases) and step 4 (docs) can run in parallel with each other after step 2.
- Verification is serial on the live host.

## Risks and open questions

- The VRAM numbers are extrapolated from a 32K benchmark and one field report. Check 4 is the real
  test.
- The native Ollama adapter (hermes-agent PR #73285) is irrelevant if we use llama.cpp.
- Hermes v0.22's own "managed llama.cpp" runtime is a desktop/CLI feature. Make sure it doesn't try
  to start a second server alongside ours.
- Upstream hermes-agent moves fast (several releases a week). Pin the lock and bump on purpose.
