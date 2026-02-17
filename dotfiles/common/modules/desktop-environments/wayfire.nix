{ config, pkgs, ... }:

{

  # Enable Wayfire compositor
  programs.wayfire = {
    enable = true;
    # package = pkgs.wayfire; # Specify Wayfire package if not using default
    plugins = with pkgs.wayfirePlugins; [
      wcm # Wayfire Config Manager
      wf-shell # Wayfire shell (panel, launcher, etc.)
      wayfire-plugins-extra # Additional plugins
    ];
  };


  services.displayManager.defaultSession = "wayfire.desktop";

  # Enable XDG desktop portal for Wayland (often needed for Flatpaks, etc.)
  environment.systemPackages = with pkgs; [

    xdg-desktop-portal-wlr # Wayland specific XDG portal for wlroots based compositors
    waybar # Customizable Wayland bar
    wofi # Application launcher (alternative to rofi for Wayland)
    mako # Notification daemon
    grim # Screenshot utility
    slurp # Region selection for grim
    wl-clipboard # Wayland clipboard utilities
    wlr-randr # RandR utility for Wayland
  ];

  # SDDM is already configured in the parent flake and supports Wayland.
  # No need to explicitly enable a display manager here.
}
