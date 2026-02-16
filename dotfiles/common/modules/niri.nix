{ config, pkgs, ... }:

{
  # Enable Niri Wayland compositor
  programs.niri.enable = true;

  # Enable the X server (Wayland)
  services.xserver.enable = true;

  # Set Niri as the default session for display managers
#   services.xserver.displayManager.defaultSession = "niri";

  # It is recommended to configure Niri's specific settings (keybindings, environment variables, etc.)
  # via Home Manager using the 'niri-flake'. This module only provides basic system-level enablement.

  security.polkit.enable = true; # polkit
  services.gnome.gnome-keyring.enable = true; # secret service
  security.pam.services.swaylock = {};
  
  programs.waybar.enable = true; # top bar
  
  environment.systemPackages = with pkgs; [
  	alacritty
  	fuzzel
  	mako
  	swaylock
  	swayidle
  	waybar
  ];
}
