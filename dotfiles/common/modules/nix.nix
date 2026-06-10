{ ... }:

{
  # Enable unfree packages
  nixpkgs.config.allowUnfree = true;

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
