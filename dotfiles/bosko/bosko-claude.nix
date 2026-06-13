{ self, pkgs, lib, ... }:

{
  home.sessionPath = [ "$HOME/.local/bin" ];

  home.file = {
    ".claude/skills/repo-creator/SKILL.md" = {
      source = "${self}/dotfiles/bosko/claude/skills/repo-creator/SKILL.md";
      force = true;
    };
    ".claude/skills/session-closer/SKILL.md" = {
      source = "${self}/dotfiles/bosko/claude/skills/session-closer/SKILL.md";
      force = true;
    };
    ".claude/skills/interview/SKILL.md" = {
      source = "${self}/dotfiles/bosko/claude/skills/interview/SKILL.md";
      force = true;
    };
    ".claude/skills/new-skill/SKILL.md" = {
      source = "${self}/dotfiles/bosko/claude/skills/new-skill/SKILL.md";
      force = true;
    };
    ".claude/skills/git-commit/SKILL.md" = {
      source = "${self}/dotfiles/bosko/claude/skills/git-commit/SKILL.md";
      force = true;
    };
    ".claude/skills/git-push/SKILL.md" = {
      source = "${self}/dotfiles/bosko/claude/skills/git-push/SKILL.md";
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
