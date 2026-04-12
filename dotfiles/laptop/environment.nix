{ pkgs, ... }:

{
  # Services
  services = {
    # Enable touchpad
    libinput.enable = true;

    # Enable printing
    printing.enable = true;

    # Enable Qbittorrent
    qbittorrent.enable = true;
  };

  # Hardware
  hardware = {
    # Bluetooth settings
    bluetooth = {
      enable = true;
      powerOnBoot = false;
      settings.General = {
        Enable = "Source,Sink,Media,Socket";
        Experimental = true;
      };
    };

    # Enable graphical interface
    graphics.enable = true;
  };

  # System packages
  environment.systemPackages = with pkgs; [
    brave
    chromium
    # claude-code
    deezer-enhanced
    discord
    element-desktop
    firefox
    freetube
    gemini-cli
    github-desktop
    gparted
    kdePackages.kate
    kitty
    megasync
    obs-studio
    onlyoffice-desktopeditors
    p7zip
    qalculate-qt
    qbittorrent
    qutebrowser
    rpi-imager
    tor-browser
    vesktop
    vivaldi
    vlc
  ];

  # Flatpaks
  services.flatpak.packages = [
    "org.kde.digikam" # Digikam
    "app.zen_browser.zen" # Zen Browser
  ];
}
