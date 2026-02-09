{ config, lib, pkgs, ... }:

{
  # Set home-manager state version
  home.stateVersion = "25.11";   # ← do NOT change this later — read the comment in home-manager release notes

  # Packages
  home.packages = with pkgs; [
    kitty
    starship
  ];

  # Kitty
  home.file.".config/kitty/kitty.conf" = {
    source = config.lib.file.mkOutOfStoreSymlink "./dotfiles/common/configs/kitty.conf";
    force = true;
  };

  # Starship
  home.file.".config/starship.toml" ={
    source = config.lib.file.mkOutOfStoreSymlink "./dotfiles/common/configs/starship.toml";
    force = true;
  };
  programs.starship = {
    enable = true;
    enableZshIntegration = true;
  };
}
