{ config, pkgs, ... }:

{
  # Enable X11 server (Cinnamon is X11-native)
  services.xserver.enable = true;

  # Enable Cinnamon desktop environment
  services.xserver.desktopManager.cinnamon.enable = true;

  # Set Cinnamon as the default session for the display manager
  services.xserver.displayManager.defaultSession = "cinnamon";

  # Add common Cinnamon applications and utilities
  environment.systemPackages = with pkgs; [
    cinnamon.cinnamon-control-center
    cinnamon.nemo # File manager
    cinnamon.gnome-terminal # Often used in Cinnamon, or an alternative
    # Add other desired Cinnamon applications here
  ];
}
