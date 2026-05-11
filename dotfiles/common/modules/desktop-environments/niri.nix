{ pkgs, inputs, ... }:

{
  programs = {
    # Enable Niri
    niri.enable = true;

    # Enable xwayland
    xwayland.enable = true;
  };

  # Enable x11
  services.xserver.enable = true;

  # Enable Dank Material Shell via Home Manager
  home-manager.users.bosko = {
    imports = [ inputs.dms.homeModules.dank-material-shell ];
    programs.dank-material-shell.enable = true;
    programs.dank-material-shell.systemd.enable = true;

    # Screen locker (programs.swaylock NixOS module removed upstream; use HM)
    programs.swaylock.enable = true;

    # Idle management: lock screen after 5 minutes (services.swayidle NixOS module removed upstream; use HM)
    services.swayidle = {
      enable = true;
      timeouts = [
        { timeout = 300; command = "${pkgs.swaylock}/bin/swaylock -f"; }
      ];
    };
  };

  # Common Wayland utilities that are generally useful with any Wayland compositor
  environment.systemPackages = with pkgs; [
    # Replaced by DMS:
    # waybar # Customizable Wayland bar
    # rofi # Application launcher
    # swaylock # Screen locker
    # mako # Notification daemon

    fuzzel # Application launcher
    grim # Screenshot utility
    slurp # Region selection for grim
    wl-clipboard # Wayland clipboard utilities
    wlr-randr # RandR utility for Wayland
    xwayland
  ];
}
