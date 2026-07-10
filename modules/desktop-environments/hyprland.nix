{ pkgs, ... }:

{
  # Enable Hyprland program
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
    package = pkgs.hyprland;
  };

  # Enable the XDG portal for Hyprland
  environment.systemPackages = with pkgs; [
    grim # Screenshot utility
    mako # Notification daemon
    rofi # Application launcher
    slurp # Region selection for grim
    swayidle # Idle management daemon
    swaylock # Screen locker
    waybar # Customizable Wayland bar
    wl-clipboard # Wayland clipboard utilities
    wlr-randr # RandR utility for Wayland
    xdg-desktop-portal-hyprland
  ];

  # Configure services for Hyprland
  # You may need to configure your display manager to start Hyprland
}
