{ ... }:

{
  # Enable unfree packages
  nixpkgs.config.allowUnfree = true;

  # Custom packages not (yet) in nixpkgs live under pkgs/ (see pkgs/default.nix)
  # and are exposed via this overlay so any module can reach them as plain
  # pkgs.<name>, same as an upstream package.
  nixpkgs.overlays = [ (import ../pkgs) ];

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
