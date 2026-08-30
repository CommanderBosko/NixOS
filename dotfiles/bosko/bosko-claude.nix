{
  self,
  pkgs,
  lib,
  osConfig,
  ...
}:

{
  home.sessionPath = [ "$HOME/.local/bin" ];

  home.file = {
    # Global standing instructions loaded in every project (currently: pair
    # /init with the claude-rules skill). Plain file, not a skill.
    ".claude/CLAUDE.md" = {
      source = "${self}/dotfiles/bosko/claude/CLAUDE.md";
      force = true;
    };
    # Shared lib for global skills that need it (mirrors the project-local
    # .claude/lib/ convention). find-transcript-dir.sh (cwd-to-slug
    # derivation) is used by skill-upgrade, session-closer, and
    # skill-suggestion. find-last-skill-invocation.sh / list-transcripts-since.sh
    # (scope a log review to "since I last ran") are used by skill-suggestion,
    # skill-upgrade, skill-audit, and session-closer.
    ".claude/skills/lib" = {
      source = "${self}/dotfiles/bosko/claude/skills/lib";
      recursive = true;
      force = true;
    };
    # Recursive dir symlink: covers SKILL.md + scripts/ (create-repo.sh).
    ".claude/skills/repo-creator" = {
      source = "${self}/dotfiles/bosko/claude/skills/repo-creator";
      recursive = true;
      force = true;
    };
    # Recursive dir symlink: covers SKILL.md + scripts/ (rotate-session-summary.sh).
    # New sibling files under this skill need no further wiring.
    ".claude/skills/session-closer" = {
      source = "${self}/dotfiles/bosko/claude/skills/session-closer";
      recursive = true;
      force = true;
    };
    # Recursive dir symlink: covers SKILL.md + assets/ (brief-template.md).
    ".claude/skills/interview" = {
      source = "${self}/dotfiles/bosko/claude/skills/interview";
      recursive = true;
      force = true;
    };
    # Recursive dir symlink: covers SKILL.md + assets/ (skill-template.md).
    ".claude/skills/new-skill" = {
      source = "${self}/dotfiles/bosko/claude/skills/new-skill";
      recursive = true;
      force = true;
    };
    # Recursive dir symlink: covers SKILL.md + scripts/ (git-commit.sh).
    ".claude/skills/git-commit" = {
      source = "${self}/dotfiles/bosko/claude/skills/git-commit";
      recursive = true;
      force = true;
    };
    # Recursive dir symlink: covers SKILL.md + scripts/ (push.sh).
    ".claude/skills/git-push" = {
      source = "${self}/dotfiles/bosko/claude/skills/git-push";
      recursive = true;
      force = true;
    };
    ".claude/skills/commit-and-push/SKILL.md" = {
      source = "${self}/dotfiles/bosko/claude/skills/commit-and-push/SKILL.md";
      force = true;
    };
    # Recursive dir symlink: covers SKILL.md + scripts/ (search-pkg.sh).
    ".claude/skills/search-pkg" = {
      source = "${self}/dotfiles/bosko/claude/skills/search-pkg";
      recursive = true;
      force = true;
    };
    ".claude/skills/skill-suggestion/SKILL.md" = {
      source = "${self}/dotfiles/bosko/claude/skills/skill-suggestion/SKILL.md";
      force = true;
    };
    ".claude/skills/agent-suggestion/SKILL.md" = {
      source = "${self}/dotfiles/bosko/claude/skills/agent-suggestion/SKILL.md";
      force = true;
    };
    # Recursive dir symlink: covers SKILL.md + scripts/ (enumerate-skills.sh).
    ".claude/skills/skill-audit" = {
      source = "${self}/dotfiles/bosko/claude/skills/skill-audit";
      recursive = true;
      force = true;
    };
    # Recursive dir symlink: covers SKILL.md + scripts/ (find-skill-misfires.sh).
    ".claude/skills/skill-upgrade" = {
      source = "${self}/dotfiles/bosko/claude/skills/skill-upgrade";
      recursive = true;
      force = true;
    };
    # Recursive dir symlink: covers SKILL.md + assets/ (rules.md).
    ".claude/skills/claude-rules" = {
      source = "${self}/dotfiles/bosko/claude/skills/claude-rules";
      recursive = true;
      force = true;
    };
    # Recursive dir symlink: covers SKILL.md + assets/ (loop-template.md).
    ".claude/skills/create-loop" = {
      source = "${self}/dotfiles/bosko/claude/skills/create-loop";
      recursive = true;
      force = true;
    };
    # Recursive dir symlink: covers SKILL.md + assets/ (secret-scan templates) + scripts/ (lint).
    ".claude/skills/create-secret-scan" = {
      source = "${self}/dotfiles/bosko/claude/skills/create-secret-scan";
      recursive = true;
      force = true;
    };
    ".claude/skills/improve-system/SKILL.md" = {
      source = "${self}/dotfiles/bosko/claude/skills/improve-system/SKILL.md";
      force = true;
    };
    ".claude/skills/research/SKILL.md" = {
      source = "${self}/dotfiles/bosko/claude/skills/research/SKILL.md";
      force = true;
    };
    ".claude/skills/ship-skill/SKILL.md" = {
      source = "${self}/dotfiles/bosko/claude/skills/ship-skill/SKILL.md";
      force = true;
    };
    # Recursive dir symlink: covers SKILL.md + scripts/ (collect-boot-diagnostics.sh).
    ".claude/skills/boot-error-triage" = {
      source = "${self}/dotfiles/bosko/claude/skills/boot-error-triage";
      recursive = true;
      force = true;
    };
    # Recursive dir symlink: covers SKILL.md + scripts/ (find-status-docs.sh).
    ".claude/skills/resume-session" = {
      source = "${self}/dotfiles/bosko/claude/skills/resume-session";
      recursive = true;
      force = true;
    };
    # Recursive dir symlink: covers SKILL.md + assets/ (memory-template.md).
    ".claude/skills/save-memory" = {
      source = "${self}/dotfiles/bosko/claude/skills/save-memory";
      recursive = true;
      force = true;
    };
    # Single-file skill (no assets yet) — re-mines transcripts incrementally
    # to keep manager-profile.md current; see manager.md below.
    ".claude/skills/refresh-manager-profile/SKILL.md" = {
      source = "${self}/dotfiles/bosko/claude/skills/refresh-manager-profile/SKILL.md";
      force = true;
    };
    # Custom subagents (.claude/agents/*.md) — auto-discovered by the Agent tool,
    # no further registration needed beyond the symlink. Both are fan-out units
    # for existing skills' parallel sub-agent spawns (research, skill-audit).
    ".claude/agents/source-reviewer.md" = {
      source = "${self}/dotfiles/bosko/claude/agents/source-reviewer.md";
      force = true;
    };
    ".claude/agents/skill-reviewer.md" = {
      source = "${self}/dotfiles/bosko/claude/agents/skill-reviewer.md";
      force = true;
    };
    ".claude/agents/transcript-scanner.md" = {
      source = "${self}/dotfiles/bosko/claude/agents/transcript-scanner.md";
      force = true;
    };
    # `manager` is a global delegate agent that decides tasks the way this
    # user would, per manager-profile.md below — see dotfiles/bosko/claude/agents/manager.md
    # for the full contract (hard limits, training-mode toggle, PR-only landing).
    ".claude/agents/manager.md" = {
      source = "${self}/dotfiles/bosko/claude/agents/manager.md";
      force = true;
    };
    # manager's profile of the user's decision-making style, mined from Claude
    # Code transcripts across every project (dotfiles/bosko/claude/skills/refresh-manager-profile
    # keeps it current). Plain top-level file, not a skill — same pattern as
    # .claude/CLAUDE.md above.
    ".claude/manager-profile.md" = {
      source = "${self}/dotfiles/bosko/claude/manager-profile.md";
      force = true;
    };
  };

  # Once the NixOS-managed Claude Code policy is active
  # (/etc/claude-code/managed-settings.json enforces deny/ask + the fork bomb
  # hook globally), the matching keys in the personal ~/.claude/settings.json are
  # redundant — keeping them just runs the hook twice. This trims them on every
  # rebuild while leaving the file writable, so interactive /model and plugin
  # toggles still persist. Idempotent and a no-op until the managed file exists.
  home.activation.trimClaudeSettings =
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      managed=/etc/claude-code/managed-settings.json
      settings="$HOME/.claude/settings.json"
      if [ -f "$managed" ] && [ -f "$settings" ]; then
        if ${pkgs.jq}/bin/jq -e \
          '(.permissions.deny? // .permissions.ask? // .hooks?) != null' \
          "$settings" >/dev/null 2>&1; then
          tmp="$(${pkgs.coreutils}/bin/mktemp)"
          ${pkgs.jq}/bin/jq 'del(.permissions.deny, .permissions.ask, .hooks)' \
            "$settings" > "$tmp" \
            && ${pkgs.coreutils}/bin/mv "$tmp" "$settings"
          $VERBOSE_ECHO "Trimmed redundant deny/ask/hooks from $settings"
        fi
      fi
    '';

  # Declaratively reconcile the personal permissions.allow list in
  # ~/.claude/settings.json. The managed policy (/etc/claude-code/managed-settings.json,
  # see claude-code.nix) owns deny/ask/hooks system-wide; the allow list is a
  # per-user convenience that belongs here, not in the system policy. We reconcile
  # additively (rather than symlinking the file read-only) so interactive /model and
  # plugin toggles still persist and the plugin-management scripts below keep working.
  # Idempotent: only rewrites when a desired entry is missing; preserves hand-added ones.
  home.activation.claudeAllowList =
    lib.hm.dag.entryAfter [ "writeBoundary" ] (
      let
        allowList = [
          "Skill"
          "Bash(*)"
          "Read"
          "Edit"
          "Write"
          "Glob"
          "Grep"
          "WebFetch"
          "WebSearch"
          "Agent"
          "NotebookEdit"
          "TaskCreate"
          "TaskGet"
          "TaskList"
          "TaskOutput"
          "TaskStop"
          "TaskUpdate"
          "Monitor"
          "CronCreate"
          "CronList"
          "CronDelete"
          "PushNotification"
          "RemoteTrigger"
          "LSP"
          "AskUserQuestion"
          "EnterPlanMode"
          "ExitPlanMode"
        ];
      in
      ''
        settings="$HOME/.claude/settings.json"
        jq="${pkgs.jq}/bin/jq"
        desired='${builtins.toJSON allowList}'
        if [ -f "$settings" ]; then
          missing="$($jq --argjson d "$desired" \
            '($d - (.permissions.allow // [])) | length' "$settings" 2>/dev/null || echo 0)"
          if [ "$missing" != "0" ]; then
            tmp="$(${pkgs.coreutils}/bin/mktemp)"
            $jq --argjson d "$desired" \
              '.permissions.allow = ((.permissions.allow // []) + ($d - (.permissions.allow // [])))' \
              "$settings" > "$tmp" \
              && ${pkgs.coreutils}/bin/mv "$tmp" "$settings"
            $VERBOSE_ECHO "Reconciled permissions.allow in $settings"
          fi
        fi
      ''
    );

  # Declaratively reconcile Auto Mode (permissions.defaultMode + the autoMode
  # policy block) in ~/.claude/settings.json, so every host running this
  # config (gaming, laptop, natalie-laptop — vpn-server has no home-manager
  # bosko user) starts up with the same Auto Mode ruleset instead of needing
  # a manual `/auto-mode-setup` pass per machine. Full-reconcile (like
  # claudeMcpServers below), not additive like claudeAllowList: autoMode is
  # canonical repo policy, so a divergent value gets overwritten back to this.
  # See memory `auto-mode-global` for why this lives here globally rather
  # than per-project.
  home.activation.claudeAutoMode =
    lib.hm.dag.entryAfter [ "writeBoundary" ] (
      let
        autoMode = {
          soft_deny = [
            "$defaults"
            "Bash(git push --force*) in CommanderBosko/NixOS — public repo with no branch protection on main, force-push is unusually risky here"
            "Bash(nixos-rebuild switch*) / Bash(nh os switch*) — live system-activation writes outside plain dry-run/boot staging, warrants confirmation given this repo's stated normal flow is boot+reboot not live switch"
          ];
          environment = [
            "### Org-wide"
            "**Organization**: None configured"
            "**Cloud provider(s)**: None configured"
            "**Repository visibility**: PUBLIC — CommanderBosko/NixOS (github.com/CommanderBosko/NixOS), confirmed via gh API"
            "**Internal sharing / snippet hosting**: None configured — treat public paste/gist services as outside the trust boundary"
            "**Secrets management**: sops-nix — secrets committed encrypted only (secrets/common.yaml, secrets/hosts/<host>.yaml); admin age key at ~/.config/sops/age/keys.txt; plaintext secrets must never be staged or pushed"
            "**Default / protected branches**: default branch `main`; no rulesets and no protected branches listed via gh — treat as unprotected, so pushes/force-pushes to `main` on this public repo are high-consequence"
            "**CI/CD deploy targets**: None configured — repo has GitHub Actions eval-only CI (.github/workflows/check.yml running `nix flake check` + per-host deep eval); no deploy/publish step present"
            "**Network posture**: None configured"
            "**Source control**: The trusted repo (CommanderBosko/NixOS, public) and its origin remote only — no additional orgs configured"
            "**Trusted internal domains**: None configured"
            "**Trusted cloud buckets**: None configured"
            "**Key internal services**: None configured"
            "**Internal package registry**: None configured"
            "**Sensitive data locations & audiences**: sops-encrypted secrets under secrets/common.yaml and secrets/hosts/<host>.yaml (plaintext must never land in repo or Nix store); .gitignore flags *.key, *.secret, secrets.yaml, .env, .envrc as sensitive-looking; share only with audiences cleared at the [named+specifics] bar"
            "**Data retention / declassification**: None configured"
            "**Sensitive remote targets**: any namespace, host, or container whose name carries `prod` or `production` as a whole word or name segment"
            "**Protected deployment namespaces / environments**: None configured — fall back to the Sensitive remote targets heuristic"
            "**Protected IaC scopes**: IAM, RBAC, networking, quota, and node-pool resources; anything whose name or tag carries `prod` or `production` as a whole word or name segment; also treat this repo's own security.nix hardening (AppArmor, audit, PAM wheel enforcement, kexec/ASLR protections) and sops.nix/.sops.yaml recipient wiring as protected IaC scope given repo is public"
            "### User-specific"
            "**Primary use of Claude Code**: software development — single-flake NixOS configuration management (four hosts: gaming, laptop, natalie-laptop, vpn-server)"
            "**Trusted repo**: /home/bosko/NixOS (github.com/CommanderBosko/NixOS) — PUBLIC repo; only this repo's own work belongs here, content ported or first read from outside this session's repo is not its own work even if directed; secrets remain excluded from commits regardless of visibility"
            "**Org-specific CLIs**: None configured — repo-specific tooling includes `nh` (nix-helper wrapper), `rtk find` (single -iname predicate only, no compound predicates), sops via `nix shell nixpkgs#sops`"
            "routine under /home/bosko/NixOS/ prefix: package/flatpak/keybind/window-rule/secret edits via this repo's own skills (add-package, add-flatpak, add-niri-keybind, add-niri-window-rule, add-niri-fullscreen-rule, add-default-app, add-secret, bump-input), and read-only checks (ci-status, audit-config) are routine within this repo"
          ];
        };
        # Written to the store and read back with `jq --slurpfile` (rather than
        # interpolated into a shell single-quoted string) because several
        # environment entries contain apostrophes (e.g. "this repo's stated
        # normal flow") that would otherwise prematurely close the quoting.
        autoModeFile = pkgs.writeText "claude-auto-mode.json" (builtins.toJSON autoMode);
      in
      ''
        settings="$HOME/.claude/settings.json"
        jq="${pkgs.jq}/bin/jq"
        desiredMode="auto"
        autoModeFile="${autoModeFile}"
        if [ -f "$settings" ]; then
          needs_update=0
          $jq -e --arg m "$desiredMode" \
            '.permissions.defaultMode == $m' "$settings" >/dev/null 2>&1 \
            || needs_update=1
          $jq -e --slurpfile d "$autoModeFile" \
            '.autoMode == $d[0]' "$settings" >/dev/null 2>&1 \
            || needs_update=1
          if [ "$needs_update" = "1" ]; then
            tmp="$(${pkgs.coreutils}/bin/mktemp)"
            $jq --arg m "$desiredMode" --slurpfile d "$autoModeFile" \
              '.permissions.defaultMode = $m | .autoMode = $d[0]' \
              "$settings" > "$tmp" \
              && ${pkgs.coreutils}/bin/mv "$tmp" "$settings"
            $VERBOSE_ECHO "Reconciled Auto Mode defaultMode + policy in $settings"
          fi
        fi
      ''
    );

  # Declaratively register user-scope MCP servers in ~/.claude.json, making
  # each available in every project rather than only this repo.
  # ~/.claude.json is mutable state Claude Code rewrites constantly, so we
  # can't symlink it read-only; instead we reconcile one .mcpServers.<name>
  # key per server with jq. Idempotent: only rewrites when an entry is
  # missing or differs, leaving the rest of the file (project history, auth,
  # toggles) untouched.
  home.activation.claudeMcpServers =
    lib.hm.dag.entryAfter [ "writeBoundary" ] (
      let
        # mcp-nixos needs no auth — plain stdio command.
        desiredNixos = {
          type = "stdio";
          command = "mcp-nixos"; # user package, see users.nix
          args = [ ];
          env = { };
        };
        # tailscale-mcp authenticates via an OAuth client (secrets/common.yaml,
        # see modules/sops.nix) whose two KEY=VALUE lines must never sit in
        # ~/.claude.json in plaintext — command runs a wrapper that sources
        # them from the sops-decrypted file at launch time instead of passing
        # them through the `env` object below.
        desiredTailscale = {
          type = "stdio";
          command = "${pkgs.bash}/bin/bash";
          args = [
            "-c"
            "set -a; source ${osConfig.sops.secrets."tailscale-mcp-env".path}; set +a; exec tailscale-mcp"
          ];
          env = { };
        };
        servers = {
          nixos = desiredNixos;
          tailscale = desiredTailscale;
        };
      in
      ''
        claudejson="$HOME/.claude.json"
        jq="${pkgs.jq}/bin/jq"
        if [ -f "$claudejson" ]; then
          ${lib.concatStringsSep "\n" (
            lib.mapAttrsToList (name: desired: ''
              desired='${builtins.toJSON desired}'
              if ! $jq -e --argjson d "$desired" \
                '.mcpServers.${name} == $d' "$claudejson" >/dev/null 2>&1; then
                tmp="$(${pkgs.coreutils}/bin/mktemp)"
                $jq --argjson d "$desired" '.mcpServers.${name} = $d' \
                  "$claudejson" > "$tmp" \
                  && ${pkgs.coreutils}/bin/mv "$tmp" "$claudejson"
                $VERBOSE_ECHO "Registered user-scope ${name} MCP server in $claudejson"
              fi
            '') servers
          )}
        fi
      ''
    );

  # Declaratively install official-marketplace LSP plugins for Claude Code.
  # For each plugin: populate the cache from the already-cloned official marketplace,
  # register in installed_plugins.json, and enable in settings.json.
  # lspServers config lives in the official marketplace.json — no patching needed.
  home.activation.claudeOfficialPlugins =
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      official_marketplace="$HOME/.claude/plugins/marketplaces/claude-plugins-official"
      plugin_dir="$HOME/.claude/plugins"
      installed="$plugin_dir/installed_plugins.json"
      settings="$HOME/.claude/settings.json"
      jq="${pkgs.jq}/bin/jq"

      for plugin_name in pyright-lsp; do
        cache_dir="$plugin_dir/cache/claude-plugins-official/$plugin_name/1.0.0"
        plugin_id="$plugin_name@claude-plugins-official"

        if [ ! -d "$cache_dir" ] && [ -d "$official_marketplace/plugins/$plugin_name" ]; then
          ${pkgs.coreutils}/bin/mkdir -p "$cache_dir"
          ${pkgs.coreutils}/bin/cp -r \
            "$official_marketplace/plugins/$plugin_name/." "$cache_dir/"
          $VERBOSE_ECHO "Populated $plugin_name cache"
        fi

        if [ -f "$installed" ] && \
            ! $jq -e ".plugins[\"$plugin_id\"]" "$installed" >/dev/null 2>&1; then
          tmp="$(${pkgs.coreutils}/bin/mktemp)"
          $jq --arg id "$plugin_id" --arg path "$cache_dir" \
            '.plugins[$id] = [{"scope":"user","installPath":$path,"version":"1.0.0","installedAt":"2026-06-10T00:00:00.000Z","lastUpdated":"2026-06-10T00:00:00.000Z"}]' \
            "$installed" > "$tmp" \
            && ${pkgs.coreutils}/bin/mv "$tmp" "$installed"
          $VERBOSE_ECHO "Registered $plugin_id in installed_plugins.json"
        fi

        if [ -f "$settings" ] && \
            ! $jq -e ".enabledPlugins[\"$plugin_id\"]" "$settings" >/dev/null 2>&1; then
          tmp="$(${pkgs.coreutils}/bin/mktemp)"
          $jq --arg id "$plugin_id" '.enabledPlugins[$id] = true' \
            "$settings" > "$tmp" \
            && ${pkgs.coreutils}/bin/mv "$tmp" "$settings"
          $VERBOSE_ECHO "Enabled $plugin_id in settings.json"
        fi
      done
    '';

  # Declaratively install the nixd LSP plugin for Claude Code.
  # The plugin system uses three mutable JSON files plus a marketplace clone,
  # none of which can be managed with home.file. This activation script ensures
  # all four pieces are present after every rebuild — idempotent, additive only.
  home.activation.claudeNixdPlugin =
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      plugin_dir="$HOME/.claude/plugins"
      marketplace_dir="$plugin_dir/marketplaces/claude-code-lsps"
      cache_dir="$plugin_dir/cache/claude-code-lsps/nixd/1.0.0"
      known="$plugin_dir/known_marketplaces.json"
      installed="$plugin_dir/installed_plugins.json"
      settings="$HOME/.claude/settings.json"
      jq="${pkgs.jq}/bin/jq"
      lsp_patch='{"lspServers":{"nix":{"command":"nixd","extensionToLanguage":{".nix":"nix"}}}}'

      # 1. Clone marketplace if absent.
      #    This is a network operation; at boot-time activation the network may
      #    not be up yet, in which case the clone exits 128. Keep it non-fatal so
      #    a failed clone never aborts activation (which runs under `set -e`) — an
      #    abort here would skip linkGeneration and leave every home.file symlink
      #    (agents + skills) uncreated. On failure we skip the nixd plugin setup;
      #    the next interactive activation (with network) completes it.
      if [ ! -d "$marketplace_dir/.git" ]; then
        if ${pkgs.git}/bin/git clone --depth=1 \
          https://github.com/boostvolt/claude-code-lsps.git \
          "$marketplace_dir" 2>/dev/null; then
          $VERBOSE_ECHO "Cloned boostvolt/claude-code-lsps marketplace"
        else
          $VERBOSE_ECHO "nixd marketplace clone failed (no network?); skipping"
        fi
      fi

      # 2. Patch marketplace.json to add lspServers to nixd entry (needed because
      #    the community marketplace uses .lsp.json files but Claude Code only reads
      #    lspServers from marketplace.json, matching the official marketplace format)
      mp_json="$marketplace_dir/.claude-plugin/marketplace.json"
      if [ -f "$mp_json" ] && ! $jq -e \
          '[.plugins[] | select(.name=="nixd")] | .[0].lspServers' \
          "$mp_json" >/dev/null 2>&1; then
        tmp="$(${pkgs.coreutils}/bin/mktemp)"
        $jq "(.plugins[] | select(.name==\"nixd\")) += $lsp_patch" \
          "$mp_json" > "$tmp" \
          && ${pkgs.coreutils}/bin/mv "$tmp" "$mp_json"
        $VERBOSE_ECHO "Patched nixd lspServers into marketplace.json"
      fi

      # 3. Populate plugin cache if absent (only if the clone supplied the source;
      #    guarded so a skipped/failed clone above can't abort activation here)
      if [ ! -d "$cache_dir" ] && [ -d "$marketplace_dir/nixd" ]; then
        ${pkgs.coreutils}/bin/mkdir -p "$cache_dir"
        ${pkgs.coreutils}/bin/cp -r "$marketplace_dir/nixd/." "$cache_dir/"
        $VERBOSE_ECHO "Populated nixd plugin cache"
      fi

      # 4. Patch cached plugin.json to add lspServers
      cached_plugin="$cache_dir/.claude-plugin/plugin.json"
      if [ -f "$cached_plugin" ] && ! $jq -e '.lspServers' "$cached_plugin" >/dev/null 2>&1; then
        tmp="$(${pkgs.coreutils}/bin/mktemp)"
        $jq ". + $lsp_patch" "$cached_plugin" > "$tmp" \
          && ${pkgs.coreutils}/bin/mv "$tmp" "$cached_plugin"
        $VERBOSE_ECHO "Patched nixd lspServers into cached plugin.json"
      fi

      # 5. Register marketplace in known_marketplaces.json
      if [ -f "$known" ] && ! $jq -e '."claude-code-lsps"' "$known" >/dev/null 2>&1; then
        tmp="$(${pkgs.coreutils}/bin/mktemp)"
        $jq --arg loc "$marketplace_dir" \
          '. + {"claude-code-lsps": {"source": {"source": "github", "repo": "boostvolt/claude-code-lsps"}, "installLocation": $loc, "lastUpdated": "2026-06-10T00:00:00.000Z"}}' \
          "$known" > "$tmp" \
          && ${pkgs.coreutils}/bin/mv "$tmp" "$known"
        $VERBOSE_ECHO "Registered claude-code-lsps in known_marketplaces.json"
      fi

      # 6. Register plugin in installed_plugins.json
      if [ -f "$installed" ] && ! $jq -e '.plugins["nixd@claude-code-lsps"]' "$installed" >/dev/null 2>&1; then
        tmp="$(${pkgs.coreutils}/bin/mktemp)"
        $jq --arg path "$cache_dir" \
          '.plugins["nixd@claude-code-lsps"] = [{"scope":"user","installPath":$path,"version":"1.0.0","installedAt":"2026-06-10T00:00:00.000Z","lastUpdated":"2026-06-10T00:00:00.000Z"}]' \
          "$installed" > "$tmp" \
          && ${pkgs.coreutils}/bin/mv "$tmp" "$installed"
        $VERBOSE_ECHO "Registered nixd@claude-code-lsps in installed_plugins.json"
      fi

      # 7. Ensure settings.json has enabledPlugins and extraKnownMarketplaces entries
      if [ -f "$settings" ]; then
        needs_update=0
        $jq -e '.enabledPlugins["nixd@claude-code-lsps"]' "$settings" >/dev/null 2>&1 \
          || needs_update=1
        $jq -e '.extraKnownMarketplaces["claude-code-lsps"]' "$settings" >/dev/null 2>&1 \
          || needs_update=1
        if [ "$needs_update" = "1" ]; then
          tmp="$(${pkgs.coreutils}/bin/mktemp)"
          $jq --arg loc "$marketplace_dir" '
            .enabledPlugins["nixd@claude-code-lsps"] = true |
            .extraKnownMarketplaces["claude-code-lsps"] = {
              "source": {"source": "github", "repo": "boostvolt/claude-code-lsps"},
              "installLocation": $loc
            }
          ' "$settings" > "$tmp" \
            && ${pkgs.coreutils}/bin/mv "$tmp" "$settings"
          $VERBOSE_ECHO "Added nixd plugin entries to settings.json"
        fi
      fi
    '';
}
