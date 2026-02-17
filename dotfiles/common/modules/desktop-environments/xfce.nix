{ config, pkgs, ... }:

{
  # Enable X11 server (XFCE is X11-native primarily)
  services.xserver.enable = true;

  # Enable XFCE desktop environment
  services.desktopManager.xfce.enable = true;

  # Set XFCE as the default session if a display manager is enabled
  # services.displayManager.defaultSession = "xfce";

  # Add common XFCE applications and utilities
  environment.systemPackages = with pkgs; [
    xfce.thunar # File manager
    xfce.xfce4-terminal # Terminal emulator
    xfce.xfce4-appfinder # Application finder
    xfce.xfce4-panel # Panel
    xfce.xfce4-session # Session manager
    xfce.xfce4-settings # Settings manager
    xfce.xfwm4 # Window manager
    # Add other desired XFCE applications here
    # For example: xfce.xfce4-taskmanager, xfce.ristretto
  ];

  # Optional: Configure Thunar plugins
  # services.xserver.desktopManager.xfce.thunarPlugins = with pkgs.xfce; [
  #   thunar-archive-plugin
  #   thunar-media-tags-plugin
  # ];
}
