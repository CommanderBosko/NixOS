{ config, lib, pkgs, ... }:

{
  # Set home-manager state version
  home.stateVersion = "25.11";   # ← do NOT change this later — read the comment in home-manager release notes

  # Packages
  home.packages = with pkgs; [
    kitty
    starship
  ];

  # Starship
  programs.starship = {
    enable = true;
    enableZshIntegration = true;
  };
  home.file.".config/starship.toml".source = config.lib.file.mkOutOfStoreSymlink "./starship.toml";

  # home.file.".config/some-app.conf".source = ./files/some-app.conf;

  # Home Manager can manage shell session variables, XDG dirs, etc.
  # xdg.enable = true;
}
