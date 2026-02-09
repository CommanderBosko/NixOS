{ config, pkgs, ... }:

{

  home.stateVersion = "25.11";   # ← do NOT change this later — read the comment in home-manager release notes

  # Quick smoke test packages
  home.packages = with pkgs; [
  ];

  # home.file.".config/some-app.conf".source = ./files/some-app.conf;

  # Home Manager can manage shell session variables, XDG dirs, etc.
  # xdg.enable = true;
}
