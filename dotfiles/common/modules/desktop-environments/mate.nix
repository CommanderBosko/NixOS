{ config, pkgs, ... }:

{
  # Enable X11 server (MATE is X11-native)
  services.xserver.enable = true;

  # Enable MATE desktop environment
  services.xserver.desktopManager.mate.enable = true;

  # Add common MATE applications and utilities
  environment.systemPackages = with pkgs; [
    mate.mate-applets
    mate.mate-panel
    mate.mate-session
    mate.mate-terminal
    mate.caja # File manager
    # Add other desired MATE applications here
  ];
}
