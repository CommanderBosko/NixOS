{ pkgs, ... }:

{
  # Apps installed on every desktop host (flatpaks live in flatpak.nix). Host
  # environment.nix files add only their host-specific extras on top of this
  # list.

  # GVfs: userspace virtual filesystem Thunar's sidebar/GIO volume monitor
  # needs to see and auto-mount removable media (USB drives, etc.). The
  # kernel/udisks2/polkit layer already handles detection and mounting fine
  # without this (confirmed live: `udisksctl mount` works with no auth
  # prompt) — this is specifically what's missing for Thunar to notice and
  # auto-mount a drive on insertion, since Dolphin (KIO/Solid-based) never
  # needed it.
  services.gvfs.enable = true;

  # XDG portals + dconf (GTK settings) — needed by every desktop session, not
  # just SDDM's greeter.
  xdg.portal.enable = true;
  programs.dconf.enable = true;

  # System packages
  environment.systemPackages = with pkgs; [
    brave
    cava
    chromium
    cmatrix
    firefox
    freetube
    github-desktop
    gparted
    imv
    kdePackages.kate
    kitty
    megasync
    onlyoffice-desktopeditors
    pipes
    pywal # shell.nix replays its cached palette in interactive shells
    qalculate-qt
    qdirstat
    thunar
    thunar-volman # Auto-mount + notification on removable-media insertion for Thunar
    tty-clock
    vesktop
    vlc
    xarchiver
    zathura
  ];
}
