{ pkgs, ... }:

{
  # Services
  services = {
    # Enable touchpad
    libinput.enable = true;

    # Enable Qbittorrent (Web UI bound to localhost only — H-6)
    qbittorrent = {
      enable = true;
      serverConfig = {
        Preferences = {
          WebUI = {
            Address = "127.0.0.1";
          };
        };
      };
    };
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
    firefox
    freetube
    github-desktop
    gparted
    kdePackages.kate
    kdePackages.okular
    kitty
    megasync
    onlyoffice-desktopeditors
    p7zip
    qalculate-qt
    qutebrowser
    rpi-imager
    vesktop
    vlc
  ];

  # Flatpaks
  services.flatpak.packages = [
    "org.kde.digikam" # Digikam
    "app.zen_browser.zen" # Zen Browser
    "dev.aunetx.deezer" # Deezer
  ];
}
