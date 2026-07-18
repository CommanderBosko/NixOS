{ pkgs, ... }:

{
  # Apps and flatpaks installed on every desktop host. Host environment.nix
  # files add only their host-specific extras on top of this list.

  # GVfs: userspace virtual filesystem Thunar's sidebar/GIO volume monitor
  # needs to see and auto-mount removable media (USB drives, etc.). The
  # kernel/udisks2/polkit layer already handles detection and mounting fine
  # without this (confirmed live: `udisksctl mount` works with no auth
  # prompt) — this is specifically what's missing for Thunar to notice and
  # auto-mount a drive on insertion, since Dolphin (KIO/Solid-based) never
  # needed it.
  services.gvfs.enable = true;

  # System packages
  environment.systemPackages = with pkgs; [
    brave
    chromium
    firefox
    freetube
    github-desktop
    gparted
    imv
    kdePackages.kate
    kitty
    megasync
    onlyoffice-desktopeditors
    qalculate-qt
    thunar
    thunar-volman # Auto-mount + notification on removable-media insertion for Thunar
    vesktop
    vlc
    xarchiver
    zathura
  ];

  # Flatpaks
  services.flatpak.packages = [
    "dev.aunetx.deezer" # Deezer
    "org.kde.digikam" # Digikam
    "app.zen_browser.zen" # Zen Browser
  ];
}
