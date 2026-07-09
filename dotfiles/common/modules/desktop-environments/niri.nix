{ pkgs, inputs, self, ... }:

{
  programs = {
    # Enable Niri
    niri.enable = true;

    # Enable xwayland
    xwayland.enable = true;
  };

  services = {
    # Enable x11
    xserver.enable = true;

    # Plasma auto-enables these two as defaults; bare compositors like Niri
    # don't, so DMS's System Check flags them as unavailable without this.
    accounts-daemon.enable = true;
    power-profiles-daemon.enable = true;
  };

  # Enable Dank Material Shell via Home Manager
  home-manager.users.bosko = {
    imports = [ inputs.dms.homeModules.dank-material-shell ];
    programs.dank-material-shell.enable = true;
    programs.dank-material-shell.systemd.enable = true;

    # Niri config (input, layout, binds, window rules). DMS-generated files under
    # ~/.config/niri/dms/ (theme/output state driven by its own settings UI) are
    # left unmanaged on purpose.
    home.file.".config/niri/config.kdl" = {
      source = "${self}/dotfiles/common/configs/niri-config.kdl";
      force = true;
    };

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
    xwayland-satellite # Niri (>= 25.08) spawns this itself for X11-only apps; must be in PATH
  ];
}
