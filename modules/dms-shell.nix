# Dank Material Shell (DMS) stack shared by the bare-compositor DE modules
# (desktop-environments/niri.nix and hyprland.nix): DMS itself, the Qt/KDE
# theming glue that lets it retheme non-GTK apps, screen lock/idle, and the
# system services and Wayland utilities its System Check expects. Compositor-
# specific wiring stays in each DE module. Imported by those modules (not by
# flake.nix), which set the options below.
{ config, lib, pkgs, inputs, ... }:

let
  cfg = config.dmsShell;
in
{
  options.dmsShell = {
    users = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      description = "Users who get DMS and its theming/idle Home Manager config.";
    };
    idleLockTimeout = lib.mkOption {
      type = lib.types.ints.positive;
      description = "Seconds of inactivity before DMS locks the screen (seeded into its settings.json if unset).";
    };
  };

  config = {
    home-manager.users = lib.genAttrs cfg.users (_: { config, lib, pkgs, ... }: {
      imports = [ inputs.dms.homeModules.dank-material-shell ];
      programs.dank-material-shell.enable = true;
      programs.dank-material-shell.systemd.enable = true;

      # qt6ct only touches this file's mtime to trigger live theme reloads — it
      # never creates it from scratch. Without it existing, DMS's matugen color
      # file (~/.config/qt6ct/colors/matugen.conf, left unmanaged/regenerated
      # per wallpaper change) is generated but never applied, so Qt apps like
      # qBittorrent stay on Qt's default light style.
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

      # Full KDE Frameworks apps (kate, dolphin, KIO/KConfig apps generally)
      # take their palette from KColorScheme reading kdeglobals, not from
      # QT_QPA_PLATFORMTHEME. Outside Plasma no kded keeps kdeglobals' "current
      # scheme" pointer live, so they fall back to Breeze light even though
      # qt6ct is themed. `ColorScheme=*` makes KColorScheme defer to the live
      # Qt platform theme. Set via kwriteconfig6 rather than home.file because
      # KDE apps write kdeglobals back at runtime (a read-only store symlink
      # would break that). Deliberately unconditional: `nh os boot` activates
      # before any session exists, so there is no XDG_CURRENT_DESKTOP to gate
      # on, and a Plasma session re-applies its own ColorScheme at login anyway.
      home.activation.kdeColorScheme = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        run ${pkgs.kdePackages.kconfig}/bin/kwriteconfig6 --file kdeglobals --group UiSettings --key ColorScheme '*'
      '';

      # Idle lock is DMS's own (IdleService's ext-idle-notify monitor, with
      # fade-to-lock), not swayidle. DMS ships that timer disabled (0), so
      # seed the AC and battery lock timeouts into its settings.json. Only
      # keys that aren't set get seeded, so a value picked in DMS Settings ->
      # Power & Sleep (including "Never", stored as 0) wins. DMS watches the
      # file and reloads it live. settings.json stays unmanaged (a
      # programs.dank-material-shell.settings store symlink would make DMS's
      # UI read-only). A missing file is skipped: DMS creates it on first
      # launch with its configVersion, and the next activation seeds it.
      home.activation.dmsIdleLockTimeout = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        settings="${config.xdg.configHome}/DankMaterialShell/settings.json"
        if [[ -f "$settings" ]] \
          && ! ${pkgs.jq}/bin/jq -e 'has("acLockTimeout") and has("batteryLockTimeout")' "$settings" >/dev/null 2>&1; then
          if [[ -v DRY_RUN ]]; then
            echo "Would seed DMS idle-lock timeout (${toString cfg.idleLockTimeout}s) into $settings"
          elif ${pkgs.jq}/bin/jq --argjson t ${toString cfg.idleLockTimeout} \
              '.acLockTimeout //= $t | .batteryLockTimeout //= $t' "$settings" > "$settings.hm-tmp"; then
            run mv "$settings.hm-tmp" "$settings"
          else
            rm -f "$settings.hm-tmp"
            warnEcho "Couldn't seed DMS idle-lock timeout: $settings isn't valid JSON"
          fi
        fi
      '';

      # Manual fallback locker only (e.g. from a TTY with WAYLAND_DISPLAY
      # set, if DMS dies mid-lock). Never call it while DMS is running: DMS
      # follows any session lock it sees and tries to engage its own, which
      # niri refuses while swaylock holds the lock. That retry loop churned
      # GL lock surfaces until quickshell aborted on NVIDIA (2026-10-12).
      programs.swaylock.enable = true;
    });

    services = {
      # Plasma auto-enables these as defaults; bare compositors don't, so DMS's
      # System Check flags them as unavailable without this. upower is what
      # feeds DMS's battery widget and Settings page — without upowerd DMS has
      # no battery data at all.
      accounts-daemon.enable = true;
      power-profiles-daemon.enable = true;
      upower.enable = true;
    };

    # qt6ct-kde theme integration so Qt apps (e.g. qBittorrent, kate) follow
    # DMS's matugen-generated dark/light theme instead of Qt's default light style.
    environment.sessionVariables.QT_QPA_PLATFORMTHEME = "qt6ct";

    # Unwrapped Qt binaries only search the plugin dirs baked into their own
    # RPATH at build time, which never include unrelated packages like qt6ct,
    # so libqt6ct.so can't be found. Point every session app at the system
    # profile's plugin dir (which has qt6ct, via systemPackages below) so
    # QT_QPA_PLATFORMTHEME=qt6ct above can actually resolve.
    environment.profileRelativeSessionVariables.QT_PLUGIN_PATH = [ "/lib/qt-6/plugins" ];

    # Wayland utilities useful with any bare compositor; DMS replaces the
    # bar, launcher, notification daemon and lock UI.
    environment.systemPackages = with pkgs; [
      fuzzel # Application launcher
      grim # Screenshot utility
      kdePackages.qt6ct # Qt theme engine so Qt apps follow DMS's matugen theme
      playerctl # MPRIS media control (media keys)
      slurp # Region selection for grim
      wl-clipboard # Wayland clipboard utilities
      wlr-randr # RandR utility for Wayland
    ];
  };
}
