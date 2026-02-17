{ config, pkgs, ... }:

{
  services.xserver = {
    # Enable X11 server (XFCE is X11-native primarily)
    enable = true;
  
    # Enable XFCE desktop environment
    desktopManager.xfce.enable = true;
  };

  # Enable SDDM display manager
  services.displayManager.sddm.enable = true;
  services.displayManager.sddm.theme = "breeze";

  # Set XFCE as the default session if a display manager is enabled
  services.displayManager.defaultSession = "xfce.desktop";

  # Add common XFCE applications and utilities
  environment.systemPackages = with pkgs; [
    sddm # The SDDM display manager
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
