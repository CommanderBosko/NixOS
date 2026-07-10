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
  home-manager.users.bosko = { config, ... }: {
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

  # qt6ct-kde theme integration so Qt apps (e.g. qBittorrent) follow DMS's
  # matugen-generated dark/light theme instead of Qt's default light style
  environment.sessionVariables.QT_QPA_PLATFORMTHEME = "qt6ct";

  # Common Wayland utilities that are generally useful with any Wayland compositor
  environment.systemPackages = with pkgs; [
    # Replaced by DMS:
    # waybar # Customizable Wayland bar
    # rofi # Application launcher
    # swaylock # Screen locker
    # mako # Notification daemon

    fuzzel # Application launcher
    grim # Screenshot utility
    kdePackages.qt6ct # Qt theme engine so Qt apps follow DMS's matugen theme
    slurp # Region selection for grim
    wl-clipboard # Wayland clipboard utilities
    wlr-randr # RandR utility for Wayland
    xwayland-satellite # Niri (>= 25.08) spawns this itself for X11-only apps; must be in PATH
  ];
}
