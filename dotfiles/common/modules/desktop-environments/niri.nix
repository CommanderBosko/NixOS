{ config, pkgs, ... }:

{
  # Enable Niri compositor
  programs.niri = {
    enable = true;
    # Niri handles xwayland internally, so explicit xwayland.enable might not be needed here
    # or it might depend on global xserver settings.
  };
  
  # Common Wayland utilities that are generally useful with any Wayland compositor
  environment.systemPackages = with pkgs; [
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
}
