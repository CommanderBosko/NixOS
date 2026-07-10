{ pkgs, ... }:

{
  services = {
    # Enable X11 server (Budgie is X11-native)
    xserver.enable = true;

    # Enable Budgie desktop environment
    desktopManager.budgie.enable = true;
  };

  # Add common Budgie applications and utilities
  environment.systemPackages = with pkgs; [
    budgie-control-center # Budgie's settings panel
    budgie-desktop # The main Budgie desktop package
    # Add other desired Budgie applications here
  ];
}
