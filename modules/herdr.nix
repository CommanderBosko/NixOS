# Herdr: terminal agent multiplexer (per-pane agent state for Claude Code, Codex,
# etc.). Desktop-only (desktopModules, not commonModules).
{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    herdr
  ];
}
