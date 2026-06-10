{ pkgs, ... }:

{
  # Enable Wayfire compositor
  programs.wayfire = {
    enable = true;
    # package = pkgs.wayfire; # Specify Wayfire package if not using default
    plugins = with pkgs.wayfirePlugins; [
      wayfire-plugins-extra # Additional plugins
      wcm # Wayfire Config Manager
      wf-shell # Wayfire shell (panel, launcher, etc.)
    ];
  };

  # Enable XDG desktop portal for Wayland (often needed for Flatpaks, etc.)
  environment.systemPackages = with pkgs; [
    grim # Screenshot utility
    mako # Notification daemon
    slurp # Region selection for grim
    waybar # Customizable Wayland bar
    wl-clipboard # Wayland clipboard utilities
    wlr-randr # RandR utility for Wayland
    wofi # Application launcher (alternative to rofi for Wayland)
    xdg-desktop-portal-wlr # Wayland specific XDG portal for wlroots based compositors
  ];

  # SDDM is already configured in the parent flake and supports Wayland.
  # No need to explicitly enable a display manager here.
}
