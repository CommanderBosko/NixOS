# Overlay exposing the custom packages in this directory as plain pkgs.<name>
# (wired in via nixpkgs.overlays in modules/nix.nix). To add a package: drop
# <name>.nix here and add one line below.
final: _prev: {
  tailscale-mcp = final.callPackage ./tailscale-mcp.nix { };
}
