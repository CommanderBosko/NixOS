{ config, inputs, lib, pkgs, ... }:

# Hermes Agent on every desktop host (desktopModules). Main model: OpenRouter
# deepseek/deepseek-v4-flash (2026-11-19: the full 31-item competency suite
# scored 88.5 on it against 53.8 for the old local Qwen3.5-9B). The key reaches
# ~/.hermes/.env through environmentFiles from the sops secret "hermes-env"
# (KEY=VALUE lines in secrets/desktop.yaml, one key for all desktops), never the
# store. Hermes sends file contents and tool output to OpenRouter, so the
# guardrails below stay on.
#
# The local llama.cpp + Qwen3.5-9B stack was removed 2026-11-19 (it stayed
# declared but unused, and every gaming rebuild still carried the CUDA build and
# the 5 GB GGUF). It lives in git history (up to 7b5b696) and in
# docs/plans/hermes-agent-local-llm.md.
#
# Hermes runs as bosko via the upstream Home Manager module, with
# HERMES_HOME = ~/.hermes. The NixOS module's shared /var/lib/hermes (owned by
# a "hermes" system user, bosko in its group) no longer works: the CLI now
# refuses to attach to a gateway whose HERMES_HOME isn't owned by the calling
# uid ("unsafe_control_path"). CLI-only: no gateway.enable, since `hermes`
# spawns its own gateway on demand and exits it when idle.
#
# Host-only additions go in hosts/<host>/hermes-agent.nix and merge into
# hermesHomeFiles (gaming's Proton-mail and monitoring skills).
let
  memoryCheck = pkgs.writers.writePython3Bin "hermes-memory-check" {
    flakeIgnore = [ "E501" ];
  } (builtins.readFile ./hermes-memory-check.py);
in
{
  # OpenRouter key for Hermes, as an env file like pinchflat-env. One key shared
  # by every desktop (secrets/desktop.yaml). owner=bosko so the user-level Home
  # Manager activation can read it without root.
  sops.secrets."hermes-env" = {
    sopsFile = ../secrets/desktop.yaml;
    owner = "bosko";
  };

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

      # The module deep-merges these settings into the live config.yaml, so a
      # key dropped from here would linger from the local-model era: the old
      # base_url and the dummy api_key "local" must be nulled out, or Hermes
      # would send OpenRouter the wrong key to the wrong URL. Context length is
      # auto-detected from OpenRouter.
      # (The local Qwen block, provider "custom" at 127.0.0.1:8080, went away with
      # the llama.cpp stack; it is in git history.)
      settings.model = {
        provider = "openrouter";
        default = "deepseek/deepseek-v4-flash";
        base_url = null;
        api_key = null;
        api_mode = null;
        context_length = null;
      };
      # OPENROUTER_API_KEY=... (mode 600 in .env once activation merges it).
      environmentFiles = [ config.sops.secrets."hermes-env".path ];

      # Same MCP servers as Claude Code (dotfiles/bosko/claude-hm/mcp.nix).
      mcpServers = {
        nixos.command = "${pkgs.mcp-nixos}/bin/mcp-nixos";
        tailscale = {
          command = "${pkgs.bash}/bin/bash";
          args = [
            "-c"
            "set -a; source ${config.sops.secrets."tailscale-mcp-env".path}; set +a; exec ${pkgs.tailscale-mcp}/bin/tailscale-mcp"
          ];
        };
      };
      # Full tailnet management for Hermes (user decision 2026-11-27): all 94
      # tools, writes included, and no approval prompt per call. It was
      # read-only + "untrusted" (the 39 readOnlyHint tools) while the model was
      # a local 64K-context one, where the extra schemas cost ~19K tokens; the
      # model is on OpenRouter now. The blast radius is the OAuth client behind
      # tailscale-mcp-env: devices, routes, dns, policy_file and auth_keys (no
      # oauth_keys). The tools that mint or reshape credentials stay off
      # (user decision 2026-11-27): create_key makes auth keys, OAuth clients
      # and federated identities in one tool, create_oauth_app makes OAuth
      # apps, update_key can widen an existing key's scopes, delete_key can
      # revoke the connector's own credentials. include = null rather than just
      # omitted: config.yaml is deep-merged, so a removed key would survive on a
      # host that already carries the old read-only filter. A running Hermes
      # keeps its MCP tool list from startup: restart it (gateway included) to
      # pick this up.
      settings.mcp_servers.tailscale = {
        tools.include = null;
        tools.exclude = [
          "tailscale_create_key"
          "tailscale_create_oauth_app"
          "tailscale_update_key"
          "tailscale_delete_key"
        ];
        trust = "trusted";
      };

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
      # Agent-created skills are written directly, with no review step. Set this
      # back to true to stage them in ~/.hermes/pending/skills for review
      # (/skills approve), the same gate-before-save as the memory checker.
      settings.skills.write_approval = false;

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
      # Hermes also caps every pre_tool_call callback at
      # plugins.hook_callback_timeout (default 30 s), whatever the hook's own
      # timeout says. A `claude -p` check takes ~45 s, so the first memory
      # save timed out and Hermes then failed closed on EVERY tool call for 60 s
      # ("callback timed out or is still running"); the 9B model read that as a
      # system-wide outage. Keep this at or above the hook timeout above.
      settings.plugins.hook_callback_timeout = 120;

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
      }).files;
    };
  };
}
