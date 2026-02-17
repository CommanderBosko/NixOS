{ config, pkgs, ... }:

{

  services = {
  	xserver = {
      # Enable X11 server (Cinnamon is X11-native)
      enable = true;

      # Enable Cinnamon desktop environment
      desktopManager.cinnamon.enable = true;
    };
    
    # Set Cinnamon as the default session for the display manager
    displayManager.defaultSession = "cinnamon";
  };

  # Add common Cinnamon applications and utilities
  environment.systemPackages = with pkgs; [
    cinnamon-control-center
    nemo # File manager
    gnome-terminal # Often used in Cinnamon, or an alternative
    # Add other desired Cinnamon applications here
  ];
}
