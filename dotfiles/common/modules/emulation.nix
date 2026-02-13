{ config, lib, pkgs, ... }:

{
  # Flatpak
  services.flatpak = {
    enable = true;
    update.onActivation = true;

    # Flatpak packages
    packages = [
      "com.github.tchx84.Flatseal" # Flatseal
    ];
  };

  programs = {
    # Xwayland
    xwayland.enable = true;

    # Appimages
    appimage = {
      enable = true;
      binfmt = true;
    };
  };

  # Other emulation packages
  environment.systemPackages = with pkgs; [
    appimage-run
    bottles
    flatpak
    gearlever
    wine
    winetricks
    xwayland
  ];
}
