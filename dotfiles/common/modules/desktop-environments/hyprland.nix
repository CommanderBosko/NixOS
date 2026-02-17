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
    sddm # The SDDM display manager
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

  services.displayManager.sddm.enable = true;
  services.displayManager.sddm.theme = "breeze";
  services.displayManager.defaultSession = "hyprland";

  # Configure services for Hyprland
  # You may need to configure your display manager to start Hyprland
}
