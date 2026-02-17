{ config, pkgs, ... }:

{
  services.xserver = {
    # Enable X11 server (MATE is X11-native)
    enable = true;
    
    # Enable MATE desktop environment
    desktopManager.mate.enable = true;
  };

  # Enable SDDM display manager
  services.displayManager.sddm.enable = true;
  services.displayManager.sddm.theme = "breeze";
  services.displayManager.defaultSession = "mate.desktop";


  # Add common MATE applications and utilities
  environment.systemPackages = with pkgs; [
    sddm # The SDDM display manager
    mate.mate-panel-with-applets
    mate.mate-terminal
    mate.caja # File manager
    # Add other desired MATE applications here
  ];
}
