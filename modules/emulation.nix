{ pkgs, ... }:

{
  programs = {
    # Xwayland
    xwayland.enable = true;

    # Appimages
    appimage = {
      enable = true;
      binfmt = true;
    };
  };

  # Windows/AppImage compatibility packages
  environment.systemPackages = with pkgs; [
    appimage-run
    wine
    winetricks
  ];
}
