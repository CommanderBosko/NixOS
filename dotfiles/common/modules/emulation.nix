{ pkgs, ... }:

{
  # Flatpak
  services.flatpak = {
    enable = true;
    update.onActivation = true;

    # Flatpak packages
    packages = [
      "com.github.tchx84.Flatseal" # Flatseal
      "it.mijorus.gearlever" # Gear Lever
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
    flatpak
    wine
    winetricks
    xwayland
  ];
}
