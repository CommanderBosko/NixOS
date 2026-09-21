{ pkgs, lib, inputs, self, ... }:

let
  # TEMPORARY: xwayland-satellite 0.8.2 broke Steam's dropdown menus under
  # niri (Supreeeme/xwayland-satellite#156) — 0.8.2's own changelog admits
  # "fixes for some popup regressions", implying 0.8.1 introduced ones it
  # didn't fully undo. Pin just this package back to 0.8.1 via the dedicated
  # nixpkgs-xwayland-satellite-pin input (flake.nix) rather than holding back
  # nixpkgs itself. Remove this overlay + that input once upstream fixes the
  # regression and a newer release is confirmed good.
  xwaylandSatellitePinOverlay = final: prev: {
    xwayland-satellite =
      (import inputs.nixpkgs-xwayland-satellite-pin { inherit (prev.stdenv.hostPlatform) system; }).xwayland-satellite;
  };

  # Both bosko and natty have accounts on every niri host (gaming, laptop,
  # natalie-laptop), so both get the same DMS/niri Home Manager config.
  niriUsers = [ "bosko" "natty" ];
in
{
  imports = [ "${self}/modules/dms-shell.nix" ];

  dmsShell = {
    users = niriUsers;
    idleLockTimeout = 600;
  };

  nixpkgs.overlays = [ xwaylandSatellitePinOverlay ];

  programs = {
    # Enable Niri
    niri.enable = true;

    # Enable xwayland
    xwayland.enable = true;
  };

  # Enable x11
  services.xserver.enable = true;

  # niri-specific Home Manager config (niri config files, session gating, GTK
  # and cursor theming), layered on dms-shell.nix's per-user DMS config.
  home-manager.users = lib.genAttrs niriUsers (_: import "${self}/dotfiles/common/configs/niri-home.nix");

  # Sandboxed/flatpak apps (e.g. Deezer) can't read the dconf.settings GTK
  # theme directly — they ask the xdg-desktop-portal Settings interface
  # instead, which relays the same org/gnome/desktop/interface keys. niri had
  # no portal backend implementing that interface at all (2026-07-19), so
  # those apps got no color-scheme signal and fell back to their own default
  # (light) chrome. xdg-desktop-portal-gtk over xdg-desktop-portal-gnome for
  # the *default* portal. mkForce because upstream's programs.niri module
  # already sets this option to "gnome;gtk" at the same priority — a plain
  # assignment conflicts with it.
  #
  # ScreenCast/Screenshot are routed to gnome specifically (2026-07-30): gtk
  # doesn't implement those interfaces at all, so forcing gtk as the sole
  # default silently broke Vesktop/Discord screen-share (button did nothing,
  # no picker — DBus had no backend to hand the ScreenCast request to). niri
  # itself implements the ScreenCast/Screenshot D-Bus interfaces and
  # xdg-desktop-portal-gnome is the piece that forwards portal requests into
  # niri's own implementation — it doesn't require actual GNOME Shell.
  #
  # programs.niri already adds xdg-desktop-portal-gnome; gtk is listed here
  # because the routing below depends on it.
  xdg.portal = {
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    config.niri = lib.mkForce {
      default = [ "gtk" ];
      "org.freedesktop.impl.portal.ScreenCast" = [ "gnome" ];
      "org.freedesktop.impl.portal.Screenshot" = [ "gnome" ];
    };
  };

  environment.systemPackages = with pkgs; [
    xwayland-satellite # Niri (>= 25.08) spawns this itself for X11-only apps; must be in PATH — TEMPORARILY pinned to 0.8.1, see overlay above
  ];
}
