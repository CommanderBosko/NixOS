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
  programs.kitty = {
    enable = true;
  };
  home.file.".config/kitty/kitty.conf".source = "./kitty.conf";

  # Starship
  programs.starship = {
    enable = true;
    enableZshIntegration = true;
  };
  home.file.".config/starship.toml".source = "./starship.toml";

  # home.file.".config/some-app.conf".source = ./files/some-app.conf;

  # Home Manager can manage shell session variables, XDG dirs, etc.
  # xdg.enable = true;
}
