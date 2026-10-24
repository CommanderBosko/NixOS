# bosko's Claude Code MCP servers (registered in ~/.claude.json by
# dotfiles/bosko/claude-hm/mcp.nix) and the secrets behind them. Desktop-only:
# the headless vpn-server has no Home Manager and never needs the Tailscale API
# credentials or the Discord webhook, so those secrets live in
# secrets/desktop.yaml, which is not encrypted to vpn-server's key.
{ pkgs, inputs, ... }:

let
  # TEMPORARY (added 2026-10-24): nixpkgs 3ec63636+ marks python3.14-fastmcp-slim
  # broken (meta.broken = mcp >= 2), which breaks evaluation of mcp-nixos on every
  # desktop host, hermes-agent.nix's pkgs.mcp-nixos included. Pin just this
  # package back to nixpkgs fe132422 via the dedicated nixpkgs-mcp-pin input
  # (flake.nix) rather than holding back nixpkgs itself. Remove this overlay +
  # that input once nixpkgs fixes mcp-nixos/fastmcp-slim.
  mcpNixosPinOverlay = final: prev: {
    mcp-nixos =
      (import inputs.nixpkgs-mcp-pin { inherit (prev.stdenv.hostPlatform) system; }).mcp-nixos;
  };
in
{
  nixpkgs.overlays = [ mcpNixosPinOverlay ];

  users.users.bosko.packages = with pkgs; [
    mcp-nixos # MCP server backing the user-scope nixos server
    tailscale-mcp # MCP server backing the user-scope tailscale server; package in pkgs/tailscale-mcp.nix, overlay in pkgs/default.nix
  ];

  # Tailscale OAuth client credentials for the tailscale-mcp Claude Code
  # connector (bosko-only, wired in dotfiles/bosko/claude-hm/mcp.nix). An
  # env-file-style secret like pinchflat-env (hosts/gaming/pinchflat.nix) —
  # its decrypted content is two shell-sourceable KEY=VALUE lines, sourced
  # by a wrapper at MCP-server-launch time so the raw values never sit in
  # ~/.claude.json. owner=bosko so a user-level activation script can read
  # it without root.
  sops.secrets."tailscale-mcp-env" = {
    sopsFile = ../secrets/desktop.yaml;
    owner = "bosko";
  };

  # Discord webhook URL for the send-results Claude Code skill (bosko-only,
  # wired in dotfiles/bosko/claude/skills/send-results). owner=bosko so the
  # skill's script can read it without root. The secret value itself is
  # added by the user directly (never by an agent) via add-secret's
  # sops-secret.sh -- see send-results/SKILL.md's Setup section.
  sops.secrets."discord-webhook-url" = {
    sopsFile = ../secrets/desktop.yaml;
    owner = "bosko";
  };
}
