# Bosko-only Claude Code wiring for Home Manager, split by concern under
# claude-hm/:
#   files.nix    — ~/.claude symlinks (skills, agents, CLAUDE.md, manager-profile)
#   settings.nix — ~/.claude/settings.json reconciliation (trim, allow list, Auto Mode)
#   mcp.nix      — user-scope MCP servers in ~/.claude.json
#   plugins.nix  — LSP plugins (pyright-lsp, nixd)
{
  imports = [
    ./claude-hm/files.nix
    ./claude-hm/settings.nix
    ./claude-hm/mcp.nix
    ./claude-hm/plugins.nix
  ];

  home.sessionPath = [ "$HOME/.local/bin" ];
}
