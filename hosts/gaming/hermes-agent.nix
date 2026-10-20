{ config, inputs, lib, pkgs, ... }:

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
  memoryCheck = pkgs.writers.writePython3Bin "hermes-memory-check" {
    flakeIgnore = [ "E501" ];
  } (builtins.readFile ./hermes-memory-check.py);
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

      # Same MCP servers as Claude Code (dotfiles/bosko/claude-hm/mcp.nix).
      mcpServers = {
        nixos.command = "${pkgs.mcp-nixos}/bin/mcp-nixos";
        tailscale = {
          command = "${pkgs.bash}/bin/bash";
          args = [
            "-c"
            "set -a; source ${config.sops.secrets."tailscale-mcp-env".path}; set +a; exec ${pkgs.tailscale-mcp}/bin/tailscale-mcp"
          ];
          # Read-only tools only: all 94 schemas take ~19K tokens of the 64K
          # context. These globs match exactly the 39 readOnlyHint tools.
          tools.include = [
            "tailscale_get_*"
            "tailscale_list_*"
            "tailscale_validate_*"
            "tailscale_status"
            "tailscale_preview_acl"
          ];
        };
      };
      # Untrusted: any write-capable call still asks for approval first.
      settings.mcp_servers.tailscale.trust = "untrusted";

      # No Nous Portal hosted connectors (Notion, Slack, ...): none are used,
      # and the 9B model mistook their "connected: false" for broken MCP.
      settings.tools.connectors.enabled = false;
      # No anonymous Nous Portal identity either: Hermes minted one on its own
      # and routed web_search through Nous's gateway with it. Web search falls
      # back to the keyless public endpoints (Exa, Parallel, ...) instead.
      settings.nous.guest = false;

      # Every memory save (the memory tool and Mnemosyne's free-text writers; the
      # matcher is a full-match regex) goes to a Claude checker first (agent prompt in
      # .claude/agents/hermes-memory-checker.md). It keeps, fixes or rejects
      # the entry, and rejections tell Hermes why. Unprompted, Hermes saved task
      # narration and premature "results" as facts. Fails open. Approve it once
      # at the first interactive `hermes` run after a rebuild (first-use consent).
      settings.hooks.pre_tool_call = [
        {
          matcher = "memory|mnemosyne_remember|mnemosyne_update|mnemosyne_shared_remember";
          command = "${memoryCheck}/bin/hermes-memory-check ${pkgs.mcp-nixos}/bin/mcp-nixos";
          timeout = 120;
        }
      ];

      # Same plugins as Claude Code (dotfiles/bosko/claude-hm/plugins.nix),
      # from flake inputs so `nix flake update` bumps them. Plugins are opt-in.
      # Each is wrapped in a named derivation: the module symlinks plugins as
      # nix-managed-<name>, and a bare input source is just "source".
      extraPlugins = [
        # Hermes manifest lives in .hermes-plugin/; extraPlugins wants it at
        # the root, a "flattened" layout the plugin's loader supports.
        (pkgs.runCommand "superpowers" { } ''
          mkdir $out
          cp -r ${inputs.superpowers}/{.hermes-plugin/.,skills} $out/
        '')
        (pkgs.runCommand "ponytail" { } "ln -s ${inputs.ponytail} $out")
      ];
      settings.plugins.enabled = [
        "superpowers"
        "ponytail"
        "mnemosyne"
      ];
      # Long-term memory backend. Data stays in ~/.hermes/mnemosyne/data,
      # outside the store, so rebuilds never touch it.
      settings.memory.provider = "mnemosyne";
      hermesHomeFiles = lib.mapAttrs' (
        name: content: lib.nameValuePair "plugins/mnemosyne/${name}" content
      ) (import ./hermes-mnemosyne.nix { inherit pkgs; src = inputs.mnemosyne; }).files // {
        # How to use the user's Proton mail (hosts/gaming/proton-mail.nix).
        # Rewritten on every rebuild, so Hermes can't drift it.
        "skills/email/proton-mail/SKILL.md" = ./hermes-proton-mail-skill.md;
      };
    };
  };
}
