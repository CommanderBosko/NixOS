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
  # displayManager.gdm.enable = true; # Example display manager
  # desktopManager.gnome.enable = true; # Example desktop environment

  # You may need to configure your display manager to start Hyprland
  # For example, with GDM:
  # services.xserver.displayManager.gdm.enable = true;
  # services.xserver.displayManager.gdm.wayland = true;
  # services.xserver.desktopManager.session = [ {
  #     name = "hyprland";
  #     start = ''
  #       exec Hyprland
  #     '';
  # } ];
}
