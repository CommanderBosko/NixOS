{ pkgs, ... }:

{
  # Apps and flatpaks installed on every desktop host. Host environment.nix
  # files add only their host-specific extras on top of this list.

  # System packages
  environment.systemPackages = with pkgs; [
    brave
    chromium
    doublecmd
    firefox
    freetube
    github-desktop
    gparted
    kdePackages.ark
    kdePackages.gwenview
    kdePackages.kate
    kdePackages.okular
    kitty
    megasync
    onlyoffice-desktopeditors
    qalculate-qt
    vesktop
    vlc
  ];

  # Flatpaks
  services.flatpak.packages = [
    "dev.aunetx.deezer" # Deezer
    "org.kde.digikam" # Digikam
    "app.zen_browser.zen" # Zen Browser
  ];
}
