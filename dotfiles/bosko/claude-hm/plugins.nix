# Declaratively install Claude Code LSP plugins. The plugin system keeps its
# state in mutable JSON files plus marketplace clones, none of which can be
# managed with home.file, so these activation scripts reconcile them after every
# rebuild — idempotent, additive only.
{ pkgs, lib, ... }:

let
  shell = import ./shell.nix { inherit pkgs; };

  # Placeholder timestamp for the records written into installed_plugins.json
  # and known_marketplaces.json (Claude Code only needs a valid ISO-8601 string;
  # a constant keeps activation deterministic).
  stamp = "2026-06-10T00:00:00.000Z";

  # jq expression for a plugin's installed_plugins.json record, cached at $path.
  installRecord = ''[{"scope":"user","installPath":$path,"version":"1.0.0","installedAt":"${stamp}","lastUpdated":"${stamp}"}]'';
in
{
  # Official-marketplace LSP plugin (pyright-lsp): populate the cache from the
  # already-cloned official marketplace, register in installed_plugins.json, and
  # enable in settings.json. lspServers config lives in the official
  # marketplace.json — no patching needed.
  home.activation.claudeOfficialPlugins = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ${shell.jqEdit}
    official_marketplace="$HOME/.claude/plugins/marketplaces/claude-plugins-official"
    plugin_dir="$HOME/.claude/plugins"
    installed="$plugin_dir/installed_plugins.json"
    settings="$HOME/.claude/settings.json"
    jq="${pkgs.jq}/bin/jq"

    plugin_name=pyright-lsp
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
      claude_jq_edit "$installed" --arg id "$plugin_id" --arg path "$cache_dir" \
        '.plugins[$id] = ${installRecord}'
      $VERBOSE_ECHO "Registered $plugin_id in installed_plugins.json"
    fi

    if [ -f "$settings" ] && \
        ! $jq -e ".enabledPlugins[\"$plugin_id\"]" "$settings" >/dev/null 2>&1; then
      claude_jq_edit "$settings" --arg id "$plugin_id" '.enabledPlugins[$id] = true'
      $VERBOSE_ECHO "Enabled $plugin_id in settings.json"
    fi
  '';

  # nixd LSP plugin from the community claude-code-lsps marketplace. Needs all
  # of: the marketplace clone, a patched marketplace.json + cached plugin.json
  # (lspServers), and entries in known_marketplaces.json, installed_plugins.json
  # and settings.json.
  home.activation.claudeNixdPlugin = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ${shell.jqEdit}
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
      claude_jq_edit "$mp_json" "(.plugins[] | select(.name==\"nixd\")) += $lsp_patch"
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
      claude_jq_edit "$cached_plugin" ". + $lsp_patch"
      $VERBOSE_ECHO "Patched nixd lspServers into cached plugin.json"
    fi

    # 5. Register marketplace in known_marketplaces.json
    if [ -f "$known" ] && ! $jq -e '."claude-code-lsps"' "$known" >/dev/null 2>&1; then
      claude_jq_edit "$known" --arg loc "$marketplace_dir" \
        '. + {"claude-code-lsps": {"source": {"source": "github", "repo": "boostvolt/claude-code-lsps"}, "installLocation": $loc, "lastUpdated": "${stamp}"}}'
      $VERBOSE_ECHO "Registered claude-code-lsps in known_marketplaces.json"
    fi

    # 6. Register plugin in installed_plugins.json
    if [ -f "$installed" ] && ! $jq -e '.plugins["nixd@claude-code-lsps"]' "$installed" >/dev/null 2>&1; then
      claude_jq_edit "$installed" --arg path "$cache_dir" \
        '.plugins["nixd@claude-code-lsps"] = ${installRecord}'
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
        claude_jq_edit "$settings" --arg loc "$marketplace_dir" '
          .enabledPlugins["nixd@claude-code-lsps"] = true |
          .extraKnownMarketplaces["claude-code-lsps"] = {
            "source": {"source": "github", "repo": "boostvolt/claude-code-lsps"},
            "installLocation": $loc
          }
        '
        $VERBOSE_ECHO "Added nixd plugin entries to settings.json"
      fi
    fi
  '';
}
