{ pkgs, inputs, ... }:

{
  # Enable Niri compositor
  programs.niri = {
    enable = true;
    # Niri handles xwayland internally, so explicit xwayland.enable might not be needed here
    # or it might depend on global xserver settings.
  };

  # Enable x11
  services.xserver.enable = true;

  # Enable Dank Material Shell via Home Manager
  home-manager.users.bosko = {
    imports = [ inputs.dms.homeModules.dank-material-shell ];
    programs.dank-material-shell.enable = true;
    programs.dank-material-shell.systemd.enable = true;
  };

  home-manager.users.natty = {
    imports = [ inputs.dms.homeModules.dank-material-shell ];
    programs.dank-material-shell.enable = true;
    programs.dank-material-shell.systemd.enable = true;
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
    swayidle # Idle management daemon
    wl-clipboard # Wayland clipboard utilities
    wlr-randr # RandR utility for Wayland
  ];
}
