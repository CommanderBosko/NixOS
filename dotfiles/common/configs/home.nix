{ config, lib, pkgs, self, ... }:

{
  # Set home-manager state version
  home.stateVersion = "25.11";   # ← do NOT change this later — read the comment in home-manager release notes

  # Packages
  home.packages = with pkgs; [
    kitty
    starship
  ];

  # Kitty
  home.file.".config/kitty/kitty.conf".source = "./dotfiles/common/configs/kitty.conf";

  # Starship
  programs.starship = {
    enable = true;
    enableZshIntegration = true;
  };
  home.file.".config/starship.toml".source = "./dotfiles/common/configs/starship.toml";
}
