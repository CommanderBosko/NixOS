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

  # Niri is a pure-Wayland compositor and provides no X server of its own, so
  # X11-only apps (e.g. onlyoffice-desktopeditors, other legacy Qt/xcb apps)
  # fail with "Could not connect to any X display". xwayland-satellite supplies
  # a rootless Xwayland server for the session; run it as a user service bound
  # to the graphical session and point DISPLAY at it (package added to the
  # environment.systemPackages list below).
  environment.sessionVariables.DISPLAY = ":0";

  systemd.user.services.xwayland-satellite = {
    description = "Xwayland outside your Wayland compositor";
    bindsTo = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    wantedBy = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    serviceConfig = {
      Type = "notify";
      NotifyAccess = "all";
      ExecStart = "${pkgs.xwayland-satellite}/bin/xwayland-satellite :0";
      StandardOutput = "journal";
      Restart = "on-failure";
    };
  };

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
    xwayland-satellite # Rootless Xwayland server for X11-only apps under Niri
  ];
}
