{ pkgs, inputs, self, ... }:

let
  # DMS/niri Home Manager wiring, shared by every user who can log into a niri
  # session. Defined once and assigned to both bosko and natty below so natty
  # isn't left with the bare shared home.nix and no DMS at all.
  niriHomeConfig = { config, lib, pkgs, osConfig, ... }: {
    imports = [ inputs.dms.homeModules.dank-material-shell ];
    programs.dank-material-shell.enable = true;
    programs.dank-material-shell.systemd.enable = true;

    # DMS's systemd unit binds to graphical-session.target, which fires for
    # ANY Wayland/X11 login — not niri specifically. natalie-laptop dual-booted
    # into Plasma too for a while (Plasma dropped 2026-07-18, niri-only for
    # now), which would've started DMS's shell fighting Plasma's own panel.
    # Kept as a defensive gate in case a second session ever returns:
    # XDG_CURRENT_DESKTOP is set per-session (confirmed live: "niri" under
    # this compositor, imported into the systemd --user environment before
    # graphical-session.target is reached) and Plasma sets a different value.
    systemd.user.services.dms.Unit.ConditionEnvironment = "XDG_CURRENT_DESKTOP=niri";

    # Niri config (input, layout, binds, window rules). DMS-generated files under
    # ~/.config/niri/dms/ (theme/output state driven by its own settings UI) are
    # left unmanaged on purpose.
    home.file.".config/niri/config.kdl" = {
      source = "${self}/dotfiles/common/configs/niri-config.kdl";
      force = true;
    };

    # Per-host overlay (named workspaces / window rules that differ per
    # host), pulled in by the shared config.kdl via `include "niri-overlay.kdl"`.
    # osConfig is the top-level NixOS config, injected automatically since
    # this Home Manager config runs as a NixOS module.
    home.file.".config/niri/niri-overlay.kdl" = {
      source = "${self}/hosts/${osConfig.networking.hostName}/niri-overlay.kdl";
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

    # Full KDE Frameworks apps (kate, and KIO/KConfig apps generally) don't
    # theme off QT_QPA_PLATFORMTHEME at all — they resolve their palette via
    # KColorScheme reading kdeglobals, a completely separate path. Outside a
    # real Plasma session there's no kded daemon keeping kdeglobals' "current
    # scheme" pointer live, so they silently fall back to the hardcoded Breeze
    # light default even though qt6ct is correctly themed (as proven by
    # qBittorrent, a plain Qt app, picking up dark fine with identical env).
    # `ColorScheme=*` tells KColorScheme to defer to the live Qt platform
    # theme instead. Applied via kwriteconfig6 (not home.file) because
    # kdeglobals is actively written back by KDE apps (recent files, window
    # geometry, KFileDialog state) — force-managing the whole file as a
    # read-only nix-store symlink would break that.
    # Unconditional, on purpose: this repo's normal workflow is `rebuild`
    # (`nh os boot`), which only activates at the *next* boot — before any
    # session exists, so there is no XDG_CURRENT_DESKTOP to gate on (confirmed
    # via journalctl: hm-activate runs at boot, not at login). Previously this
    # was gated on XDG_CURRENT_DESKTOP=niri, which only ever fired if someone
    # ran an interactive `nh os switch` from inside a live niri session —
    # meaning it silently no-op'd for every boot-based rebuild. Safe to always
    # run: even on a host that boots into Plasma next (natalie-laptop dual-booted
    # both for a while; Plasma dropped 2026-07-18), Plasma's own session startup
    # re-applies its LookAndFeelPackage's ColorScheme over this on login anyway
    # (see the kded note above), so writing `*` here first doesn't stick around
    # to break it — this stays correct if Plasma ever comes back.
    home.activation.kdeColorScheme = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      run ${pkgs.kdePackages.kconfig}/bin/kwriteconfig6 --file kdeglobals --group UiSettings --key ColorScheme '*'
    '';

    # Declarative GTK theme selection so Thunar and other GTK3/4 apps look
    # the same on every niri host, instead of the previous per-host manual
    # `dconf write` (verified working on laptop, 2026-07-19). DMS manages its
    # own matugen-driven runtime theme for its shell UI and for Qt/KDE apps
    # (qt6ct.conf/kdeglobals above) but doesn't touch this GSettings schema
    # itself, so asserting it here is safe — it's just reapplied on every
    # `home-manager` activation (i.e. every rebuild). Uses dconf.settings
    # rather than a gsettings-based module because `gsettings set` fails here
    # with "No schemas installed"; dconf writes directly to the same
    # database gsettings reads from and doesn't need the schema installed to
    # be discoverable.
    dconf.settings."org/gnome/desktop/interface" = {
      gtk-theme = "Sweet-Dark";
      icon-theme = "candy-icons";
      cursor-theme = "breeze_cursors";
      color-scheme = "prefer-dark";
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

    # Home Manager's swayidle module already gates on ConditionEnvironment=
    # WAYLAND_DISPLAY, but Plasma 6 is Wayland too, so that alone doesn't
    # exclude it. mkForce swaps in the stricter, niri-specific check instead
    # of adding a second one — the type here is a single string, not a list,
    # and XDG_CURRENT_DESKTOP=niri already implies WAYLAND_DISPLAY is set.
    systemd.user.services.swayidle.Unit.ConditionEnvironment = lib.mkForce "XDG_CURRENT_DESKTOP=niri";
  };
in
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

  # Enable Dank Material Shell via Home Manager for every user who can log
  # into niri. Both bosko and natty have accounts on every niri host
  # (gaming, laptop, natalie-laptop), so both get the same block.
  home-manager.users.bosko = niriHomeConfig;
  home-manager.users.natty = niriHomeConfig;

  # qt6ct-kde theme integration so Qt apps (e.g. qBittorrent, kate) follow
  # DMS's matugen-generated dark/light theme instead of Qt's default light style
  environment.sessionVariables.QT_QPA_PLATFORMTHEME = "qt6ct";

  # Without this, apps built outside qt6ct's own closure (i.e. anything
  # not sharing their exact Nix build inputs) can't discover libqt6ct.so at
  # all: unwrapped Qt binaries only search the plugin dirs baked into their own
  # RPATH at build time, which never include unrelated packages like qt6ct.
  # This points every session app at the merged system profile's plugin dir
  # (which does include qt6ct, since it's in environment.systemPackages below),
  # so QT_QPA_PLATFORMTHEME=qt6ct above can actually be resolved.
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
    kdePackages.qt6ct # Qt theme engine so Qt apps follow DMS's matugen theme
    playerctl # MPRIS media control, used by niri-config.kdl's XF86Audio media key binds
    slurp # Region selection for grim
    wl-clipboard # Wayland clipboard utilities
    wlr-randr # RandR utility for Wayland
    xwayland-satellite # Niri (>= 25.08) spawns this itself for X11-only apps; must be in PATH
  ];
}
