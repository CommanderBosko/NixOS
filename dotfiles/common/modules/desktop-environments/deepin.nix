{ config, pkgs, ... }:

{
  # Enable X11 server (DDE is X11-native)
  services.xserver.enable = true;

  # Enable Deepin Desktop Environment
  services.xserver.desktopManager.deepin.enable = true;

  # Set DDE as the default session for the display manager
  # services.xserver.displayManager.defaultSession = "deepin"; # May need to be "deepin-unstable" or specific session name

  # Add common Deepin applications and utilities
  environment.systemPackages = with pkgs; [
    deepin.dde # The main Deepin Desktop package
    deepin.deepin-terminal # Deepin Terminal
    deepin.deepin-file-manager # Deepin File Manager (Dolphin or Nemo alternative)
    # Add other desired Deepin applications here
  ];
}
