{ pkgs, ... }:

{
  # Apps and flatpaks installed on every desktop host. Host environment.nix
  # files add only their host-specific extras on top of this list.

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
