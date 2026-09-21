{ pkgs, self, ... }:

{
  imports = [ "${self}/modules/dms-shell.nix" ];

  # DMS via Home Manager, for bosko only (unlike niri.nix, which also covers natty).
  #
  # Unlike niri, DMS ships no declarative NixOS/Home-Manager module for
  # Hyprland. Since Hyprland 0.55, DMS manages Hyprland's own config
  # imperatively at runtime instead: `dms setup` generates/migrates a Lua
  # config (~/.config/hypr/hyprland.lua + dms/*.lua fragments), sweeping any
  # existing hyprland.conf into its own `.dms-backups/` — a Nix-managed
  # hyprland.conf would just get backed up out of the way on first `dms
  # run`. Hyprland's own config (binds, layout, monitors) is deliberately left
  # unmanaged here; run `dms setup` once after first login to generate it,
  # then customize via `dms/binds-user.lua` or DMS's own Settings UI.
  dmsShell = {
    users = [ "bosko" ];
    idleLockTimeout = 300;
  };

  programs = {
    # Enable Hyprland
    hyprland = {
      enable = true;
      xwayland.enable = true;
    };
  };

  # Enable x11 (not needed for Hyprland's own Wayland session, but several
  # other non-X11-native DEs in this repo also enable it for full desktop
  # plumbing — mirrored here for consistency with niri.nix)
  services.xserver.enable = true;

  # xdg-desktop-portal-hyprland is already added by programs.hyprland.
  environment.systemPackages = with pkgs; [
    kdePackages.dolphin # File manager
  ];
}
