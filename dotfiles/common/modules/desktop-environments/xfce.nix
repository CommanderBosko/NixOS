{ config, pkgs, ... }:

{
  services.xserver = {
    # Enable X11 server (XFCE is X11-native primarily)
    enable = true;
  
    # Enable XFCE desktop environment
    desktopManager.xfce.enable = true;
  };

  # Set XFCE as the default session if a display manager is enabled
  services.displayManager.defaultSession = "xfce";

  # Add common XFCE applications and utilities
  environment.systemPackages = with pkgs; [
    thunar # File manager
    xfce4-terminal # Terminal emulator
    xfce4-appfinder # Application finder
    xfce4-panel # Panel
    xfce4-session # Session manager
    xfce4-settings # Settings manager
    xfwm4 # Window manager
    # Add other desired XFCE applications here
    # For example: xfce.xfce4-taskmanager, xfce.ristretto
  ];

  # Optional: Configure Thunar plugins
  # services.xserver.desktopManager.xfce.thunarPlugins = with pkgs.xfce; [
  #   thunar-archive-plugin
  #   thunar-media-tags-plugin
  # ];
}
