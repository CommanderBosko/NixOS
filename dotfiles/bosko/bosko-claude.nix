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

  # Two Claude Code installs coexist on purpose: modules/claude-code.nix ships
  # the nixpkgs build on every host as the declarative baseline, and where the
  # native installer's auto-updating copy exists in ~/.local/bin it comes first
  # in PATH and tracks upstream faster than nixpkgs does.
  home.sessionPath = [ "$HOME/.local/bin" ];
}
