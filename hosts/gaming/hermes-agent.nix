{ inputs, lib, pkgs, ... }:

# llama.cpp (CUDA) + Hermes Agent for gaming, on-demand.
#
# llama-server exposes an OpenAI-compatible API at http://127.0.0.1:8080/v1.
# The service is NOT started at boot (wantedBy cleared): `llm-on` / `llm-off`
# start and stop it so games get the whole GPU.  Plan and rationale:
# docs/plans/hermes-agent-local-llm.md.
#
# Model: Qwen3.5-9B IQ4_XS (unsloth, text-only), hash-pinned in the store.
#
# VRAM budget on the RTX 3070 (7.84 GB usable), estimates until verified:
#   desktop ~1.5 GB + weights ~5.2 GB + KV @ 64K q8_0 ~1.0 GiB + compute ~0.4 GB.
# Fallbacks if it doesn't fit, in order: q4_0 KV, close browser/Discord,
# n-gpu-layers 96-98, Qwen3.5-4B.
#
# Flags:
#   ctx-size 65536       Hermes refuses to run below a 64K context.  Set on the
#                        server, so there is no per-request num_ctx to lose.
#   parallel 1           slots SPLIT the context; 4 slots would be 16K each.
#   cache-type-k/v q8_0  halves the KV cache vs f16 at negligible quality cost.
#   flash-attn on        required for a quantised V cache.
#   jinja                the chat template drives tool calling.
#   reasoning-budget 0   thinking off: saves context and latency.
#
# Hermes runs as bosko via the upstream Home Manager module, with
# HERMES_HOME = ~/.hermes.  The NixOS module's shared /var/lib/hermes (owned by
# a "hermes" system user, bosko in its group) no longer works: the CLI now
# refuses to attach to a gateway whose HERMES_HOME isn't owned by the calling
# uid ("unsafe_control_path").  CLI-only: no gateway.enable, since `hermes`
# spawns its own gateway on demand and exits it when idle.
let
  model = pkgs.fetchurl {
    url = "https://huggingface.co/unsloth/Qwen3.5-9B-GGUF/resolve/main/Qwen3.5-9B-IQ4_XS.gguf";
    sha256 = "7e918aeca06c52bcb528ea6b04b4ec957e75ee8c0a73138854c0dfcf371ea429";
  };
in
{
  services.llama-cpp = {
    enable = true;
    package = pkgs.llama-cpp-cuda;
    settings = {
      host = "127.0.0.1";
      port = 8080;
      model = "${model}";
      ctx-size = 65536;
      parallel = 1;
      n-gpu-layers = 99;
      flash-attn = "on";
      cache-type-k = "q8_0";
      cache-type-v = "q8_0";
      jinja = true;
      reasoning-budget = 0;
    };
  };

  # On-demand: don't start at boot.
  systemd.services.llama-cpp.wantedBy = lib.mkForce [ ];

  home-manager.users.bosko = {
    imports = [ inputs.hermes-agent.homeManagerModules.default ];

    programs.hermes-agent.enable = true;

    services.hermes-agent = {
      enable = true;

      settings.model = {
        provider = "custom";
        default = "qwen3.5-9b";
        base_url = "http://127.0.0.1:8080/v1";
        # Non-empty dummy: the OpenAI client rejects an empty key.
        api_key = "local";
        api_mode = "chat_completions";
        context_length = 65536;
      };
    };
  };
}
