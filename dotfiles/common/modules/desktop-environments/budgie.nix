{ config, pkgs, ... }:

{
  services = {
    # Enable X11 server (Budgie is X11-native)
    xserver.enable = true;
  
    # Enable Budgie desktop environment
    desktopManager.budgie.enable = true;

    # Enable SDDM display manager
    displayManager.sddm.enable = true;
    displayManager.sddm.theme = "breeze";
    displayManager.defaultSession = "budgie.desktop";
  };

  # Add common Budgie applications and utilities
  environment.systemPackages = with pkgs; [
    sddm # The SDDM display manager
    budgie-desktop # The main Budgie desktop package
    budgie-control-center # Budgie's settings panel
    # Add other desired Budgie applications here 
  ];
}
