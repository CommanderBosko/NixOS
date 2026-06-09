{ self, pkgs, lib, ... }:

{
  home.sessionPath = [ "$HOME/.local/bin" ];

  home.file = {
    ".claude/agents/repo-creator-agent.md" = {
      source = "${self}/dotfiles/bosko/claude/agents/repo-creator-agent.md";
      force = true;
    };
    ".claude/agents/session-closer.md" = {
      source = "${self}/dotfiles/bosko/claude/agents/session-closer.md";
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
}
