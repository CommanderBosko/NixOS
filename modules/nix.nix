{ self, ... }:

{
  # Enable unfree packages
  nixpkgs.config.allowUnfree = true;

  # Custom packages not (yet) in nixpkgs live under pkgs/ and are exposed via
  # this overlay so any module can reach them as plain pkgs.<name>, same as an
  # upstream package. First user: tailscale-mcp (see pkgs/tailscale-mcp.nix),
  # the MCP server backing the user-scope `tailscale` Claude Code connector.
  nixpkgs.overlays = [
    (final: _prev: {
      tailscale-mcp = final.callPackage "${self}/pkgs/tailscale-mcp.nix" { };
    })
  ];

  # Nix settings
  nix.settings = {
    experimental-features = [
      "flakes"
      "nix-command"
    ];

    auto-optimise-store = true;
    download-buffer-size = 1024 * 1024 * 1024; # 1 GB
  };
}
