{ config, pkgs, ... }:

{
  # Enable Hyprland program
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
    package = pkgs.hyprland;
  };

  # Enable the XDG portal for Hyprland
  environment.systemPackages = with pkgs; [
    xdg-desktop-portal-hyprland
    waybar # Customizable Wayland bar
    rofi # Application launcher
    swaylock # Screen locker
    swayidle # Idle management daemon
    mako # Notification daemon
    grim # Screenshot utility
    slurp # Region selection for grim
    wl-clipboard # Wayland clipboard utilities
    wlr-randr # RandR utility for Wayland
  ];

  # Configure services for Hyprland
  # You may need to configure your display manager to start Hyprland
}
