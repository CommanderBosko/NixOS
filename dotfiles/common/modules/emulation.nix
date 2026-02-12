{ config, lib, pkgs, ... }:

{
  # Flatpak
  services.flatpak = {
    enable = true;

    remotes = [
      name = "flathub";
      location = "https://dl.flathub.org/repo/flathub.flatpakrepo";
    ];

    packages = [
      "org.kde.digikam"
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
