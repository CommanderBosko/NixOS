# Home Manager side of the niri desktop: niri config, session gating, GTK and
# cursor theming. Imported by modules/desktop-environments/niri.nix for every
# user who can log into a niri session, on top of modules/dms-shell.nix's Home
# Manager config (DMS itself, qt6ct/kdeglobals theming, swaylock/swayidle).
{ config, lib, pkgs, osConfig, self, ... }:

{
  # DMS's gtk.sh copies adw-gtk3 into ~/.local/share/themes and patches its
  # matugen colors in (without it DMS falls back to a global CSS override).
  home.packages = [ pkgs.adw-gtk3 ];

  # DMS's systemd unit binds to graphical-session.target, which fires for ANY
  # Wayland/X11 login, not just niri. Gate on XDG_CURRENT_DESKTOP (set
  # per-session and imported into the systemd --user environment before the
  # target is reached) so a second session, e.g. Plasma, never starts DMS
  # against its own panel.
  systemd.user.services.dms.Unit.ConditionEnvironment = "XDG_CURRENT_DESKTOP=niri";

  # HM's swayidle unit already gates on ConditionEnvironment=WAYLAND_DISPLAY,
  # but Plasma 6 is Wayland too. mkForce swaps in the stricter niri check
  # instead of adding a second one (the option is a single string, not a list;
  # XDG_CURRENT_DESKTOP=niri already implies WAYLAND_DISPLAY).
  systemd.user.services.swayidle.Unit.ConditionEnvironment = lib.mkForce "XDG_CURRENT_DESKTOP=niri";

  # Niri config (input, layout, binds, window rules). DMS-generated files under
  # ~/.config/niri/dms/ (theme/output state driven by its own settings UI) are
  # left unmanaged on purpose.
  home.file.".config/niri/config.kdl" = {
    source = "${self}/dotfiles/common/configs/niri-config.kdl";
    force = true;
  };

  # Per-host overlay (named workspaces / window rules that differ per host),
  # pulled in by the shared config.kdl via `include "niri-overlay.kdl"`.
  # osConfig is the top-level NixOS config, injected automatically since this
  # Home Manager config runs as a NixOS module. A host without an overlay file
  # gets an empty one, so a new niri host doesn't fail on a missing source path.
  home.file.".config/niri/niri-overlay.kdl" =
    let
      overlay = "${self}/hosts/${osConfig.networking.hostName}/niri-overlay.kdl";
    in
    {
      source = if builtins.pathExists overlay then overlay else pkgs.writeText "niri-overlay.kdl" "";
      force = true;
    };

  # Declarative GTK theme so Thunar and other GTK3/4 apps look the same on
  # every niri host and user. HM's `gtk` module writes gtk-3.0/gtk-4.0
  # settings.ini and the matching dconf keys from the same options in one
  # activation step, so they can't drift apart the way a manual dconf write +
  # hand-edited settings.ini did. DMS still manages its own matugen runtime
  # theme for the shell UI and Qt/KDE apps independently.
  #
  # The theme/iconTheme names are the literal output folder names produced by
  # the colloid overrides below (verified from a real build, not the README).
  # `colorScheme = "dark"` alone derives gtk-application-prefer-dark-theme and
  # dconf's color-scheme. gtk4.theme is set explicitly: below HM's 26.05
  # stateVersion cutover (home.stateVersion here is 25.11) it only inherits
  # gtk.theme implicitly, and that default would change silently on a bump.
  gtk = {
    enable = true;
    theme = {
      name = "Colloid-Teal-Dark";
      package = pkgs.colloid-gtk-theme.override {
        themeVariants = [ "teal" ];
        colorVariants = [ "dark" ];
      };
    };
    gtk4.theme = config.gtk.theme;
    iconTheme = {
      name = "Colloid-Teal-Dark";
      package = pkgs.colloid-icon-theme.override {
        colorVariants = [ "teal" ];
      };
    };
    colorScheme = "dark";
  };

  # Covers what the gtk module doesn't: XWayland/Qt apps that read
  # XCURSOR_THEME/XCURSOR_SIZE instead of GSettings, and a guaranteed
  # ~/.icons/default symlink. kdePackages.breeze provides breeze_cursors
  # (breeze-icons only has folder/mimetype icons). `pointerCursor.gtk.enable`
  # feeds the same package/name/size into gtk.cursorTheme, so there is one
  # declared cursor rather than two copies to keep in sync.
  home.pointerCursor = {
    enable = true;
    package = pkgs.kdePackages.breeze;
    name = "breeze_cursors";
    size = 24;
    x11.enable = true;
    gtk.enable = true;
  };
}
