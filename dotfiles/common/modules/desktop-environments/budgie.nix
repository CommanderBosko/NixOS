{ config, pkgs, ... }:

{
  # Enable X11 server (Budgie is X11-native)
  services.xserver.enable = true;

  # Enable Budgie desktop environment
  services.desktopManager.budgie.enable = true;

  # Add common Budgie applications and utilities
  environment.systemPackages = with pkgs; [
    budgie-desktop # The main Budgie desktop package
    budgie-control-center # Budgie's settings panel
    # Add other desired Budgie applications here
  ];
}
