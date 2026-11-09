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

    # herdr reads Hermes's state off the screen, and its upstream manifest
    # predates this Hermes's working UI (panes stayed idle). This local copy
    # adds the missing working rules; see the file's header for why and when
    # to drop it.
    xdg.configFile."herdr/agent-detection/hermes.toml".source = ./herdr-hermes-detection.toml;

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
        # Remote server (https://wowaudit.com/mcp): OAuth 2.1 PKCE with dynamic
        # client registration, so no API key or sops secret. The browser login
        # is a one-time imperative step, `hermes mcp login wowaudit --flow
        # browser` (no device flow: wowaudit only offers authorization_code).
        # Tokens land in ~/.hermes/mcp-tokens/, outside the store, so rebuilds
        # keep them. The login grants scope=read only, so the 18 write tools
        # (set_*, save_*, create_*, update_*, add_*, remove_*, link_*, sync_*,
        # auto_setup) would be rejected anyway; the 21 read tools below keep
        # the schemas small against the 64K context.
        wowaudit = {
          url = "https://wowaudit.com/mcp";
          auth = "oauth";
          tools.include = [
            "get_my_context"
            "get_character"
            "team_audit"
            "list_audit_fields"
            "find_recipe_crafters"
            "list_my_events"
            "list_events"
            "get_event"
            "event_insights"
            "get_event_changelog"
            "list_event_schedules"
            "list_applications"
            "get_applications"
            "list_roster"
            "list_notification_templates"
            "list_seasons"
            "list_instances"
            "list_encounter_items"
            "trinket_status"
            "wishlist_upgrades"
            "loot_history"
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

      # write_file/patch may only touch these dirs; anything else (the real
      # repo included) is hard-blocked. Shell redirects via the terminal tool
      # are NOT covered, so approvals below still matter.
      environment.HERMES_WRITE_SAFE_ROOT = "~/hermes-work:~/projects/hermes-tests";
      # Pin manual approval (a 9B "smart" judge would be worse) and refuse
      # these outright; denies hold even under --yolo. Pattern-based only:
      # execute_code scripts can bypass them. Pushes are NOT denied: main is
      # protected by a GitHub ruleset (PR + CI, no bypass), so Hermes may push
      # branches and open PRs (each asks first) but cannot merge its own.
      settings.approvals = {
        mode = "manual";
        deny = [
          "gh pr merge*"
          "nixos-rebuild*"
          "nh os *"
          "nix flake update*"
          "rm -r*"
          "sudo *"
        ];
      };
      # Agent-created skills are staged in ~/.hermes/pending/skills for review
      # (/skills approve), the same gate-before-save as the memory checker.
      settings.skills.write_approval = true;

      # Every memory save (the memory tool and Mnemosyne's writers; the
      # matcher is a full-match regex) goes to a Claude checker first (agent prompt in
      # .claude/agents/hermes-memory-checker.md). It keeps, fixes or rejects
      # the entry, and rejections tell Hermes why. Unprompted, Hermes saved task
      # narration and premature "results" as facts. Fails open. Approve it once
      # at the first interactive `hermes` run after a rebuild (first-use consent).
      settings.hooks.pre_tool_call = [
        {
          matcher = "memory|mnemosyne_(remember|update|shared_remember|remember_canonical|triple_add|batch|scratchpad_write|task_progress|import)";
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
      # herdr-agent-state is installed imperatively by `herdr integration
      # install hermes` (~/.hermes/plugins/herdr-agent-state); it only needs
      # enabling here. It reports the session id so herdr can resume the pane
      # after a restart; it does NOT drive the working/idle/blocked icons
      # (herdr detects those from the screen, see herdr-hermes-detection.toml).
      settings.plugins.enabled = [
        "superpowers"
        "ponytail"
        "mnemosyne"
        "herdr-agent-state"
      ];
      # Long-term memory backend. Data stays in ~/.hermes/mnemosyne/data,
      # outside the store, so rebuilds never touch it.
      settings.memory.provider = "mnemosyne";
      # Built from Hermes's own nixpkgs, not the system one: the plugin loads
      # native code (sqlite-vec's vec0.so, onnxruntime) into Hermes's Python,
      # and when the two nixpkgs drift apart the newer glibc symbols don't
      # resolve in the older process (GLIBC_2.43 not found, vector search off).
      hermesHomeFiles = lib.mapAttrs' (
        name: content: lib.nameValuePair "plugins/mnemosyne/${name}" content
      ) (import ./hermes-mnemosyne.nix {
        pkgs = inputs.hermes-agent.inputs.nixpkgs.legacyPackages.${pkgs.stdenv.hostPlatform.system};
        src = inputs.mnemosyne;
      }).files // {
        # How to use the user's Proton mail (hosts/gaming/proton-mail.nix).
        # Rewritten on every rebuild, so Hermes can't drift it.
        "skills/email/proton-mail/SKILL.md" = ./hermes-proton-mail-skill.md;
        # Read-only view of the monitoring stack (hosts/gaming/monitoring.nix).
        "skills/monitoring/homelab-monitoring/SKILL.md" = ./hermes-monitoring-skill.md;
      };
    };
  };
}
