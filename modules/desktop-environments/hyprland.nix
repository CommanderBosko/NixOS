{ pkgs, inputs, ... }:

{
  programs = {
    # Enable Hyprland
    hyprland = {
      enable = true;
      xwayland.enable = true;
      package = pkgs.hyprland;
    };
  };

  services = {
    # Enable x11 (not needed for Hyprland's own Wayland session, but several
    # other non-X11-native DEs in this repo also enable it for full desktop
    # plumbing — mirrored here for consistency with niri.nix)
    xserver.enable = true;

    # Plasma auto-enables these two as defaults; bare compositors like
    # Hyprland don't, so DMS's System Check flags them as unavailable without this.
    accounts-daemon.enable = true;
    power-profiles-daemon.enable = true;
  };

  # Enable Dank Material Shell via Home Manager
  home-manager.users.bosko = { config, lib, pkgs, ... }: {
    imports = [ inputs.dms.homeModules.dank-material-shell ];
    programs.dank-material-shell.enable = true;
    programs.dank-material-shell.systemd.enable = true;

    # Unlike niri, DMS ships no declarative NixOS/Home-Manager module for
    # Hyprland. Since Hyprland 0.55, DMS manages Hyprland's own config
    # imperatively at runtime instead: `dms setup` generates/migrates a Lua
    # config (~/.config/hypr/hyprland.lua + dms/*.lua fragments), sweeping any
    # existing hyprland.conf into its own `.dms-backups/` — a Nix-managed
    # hyprland.conf would just get backed up out of the way on first `dms
    # run`, the same way force-managing kdeglobals read-only would break KDE
    # apps below. Hyprland's own config (binds, layout, monitors) is
    # deliberately left unmanaged here; run `dms setup` once after first
    # login to generate it, then customize via `dms/binds-user.lua` or DMS's
    # own Settings UI.

    # qt6ct only touches this file's mtime to trigger live theme reloads — it
    # never creates it from scratch. Without it existing, DMS's matugen color
    # file (~/.config/qt6ct/colors/matugen.conf, left unmanaged/regenerated
    # per wallpaper change) is generated but never applied, so Qt apps like
    # qBittorrent stay stuck on Qt's default light style.
    home.file.".config/qt6ct/qt6ct.conf" = {
      force = true;
      text = ''
        [Appearance]
        color_scheme_path=${config.home.homeDirectory}/.config/qt6ct/colors/matugen.conf
        custom_palette=true
        icon_theme=
        standard_dialogs=default
        style=Fusion

        [Interface]
        buttonbox_layout=0
        cursor_flash_time=1000
        dialog_buttons_have_icons=1
        double_click_interval=400
        gui_effects=@Invalid()
        keyboard_scheme=2
        menus_have_icons=true
        show_shortcuts_in_context_menus=true
        stylesheets=@Invalid()
        toolbutton_style=4
        underline_shortcut=1
        wheel_scroll_lines=3

        [SettingsWindow]
        geometry=@ByteArray()

        [Troubleshooting]
        force_raster_widgets=1
        ignored_applications=@Invalid()
      '';
    };

    # Full KDE Frameworks apps (dolphin, and KIO/KConfig apps generally) don't
    # theme off QT_QPA_PLATFORMTHEME at all — they resolve their palette via
    # KColorScheme reading kdeglobals, a completely separate path (see
    # niri.nix for the full explanation). `ColorScheme=*` tells KColorScheme
    # to defer to the live Qt platform theme instead. Applied via
    # kwriteconfig6 (not home.file) because kdeglobals is actively written
    # back by KDE apps (recent files, window geometry, KFileDialog state) —
    # force-managing the whole file as a read-only nix-store symlink would
    # break that.
    home.activation.kdeColorScheme = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      run ${pkgs.kdePackages.kconfig}/bin/kwriteconfig6 --file kdeglobals --group UiSettings --key ColorScheme '*'
    '';

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

  # qt6ct-kde theme integration so Qt apps (e.g. qBittorrent, dolphin) follow
  # DMS's matugen-generated dark/light theme instead of Qt's default light style
  environment.sessionVariables.QT_QPA_PLATFORMTHEME = "qt6ct";

  # Without this, apps built outside dolphin/qt6ct's own closure can't
  # discover libqt6ct.so at all — see niri.nix for the full explanation.
  environment.profileRelativeSessionVariables.QT_PLUGIN_PATH = [ "/lib/qt-6/plugins" ];

  # Common Wayland utilities that are generally useful with any Wayland compositor
  environment.systemPackages = with pkgs; [
    # Replaced by DMS:
    # waybar # Customizable Wayland bar
    # rofi # Application launcher
    # swaylock # Screen locker
    # mako # Notification daemon

    fuzzel # Application launcher
    grim # Screenshot utility
    kdePackages.dolphin # File manager
    kdePackages.qt6ct # Qt theme engine so Qt apps follow DMS's matugen theme
    playerctl # MPRIS media control
    slurp # Region selection for grim
    wl-clipboard # Wayland clipboard utilities
    wlr-randr # RandR utility for Wayland
    xdg-desktop-portal-hyprland
  ];
}
