{ pkgs, ... }:

{
  # Services
  services = {
    # Display manager settings
    displayManager = {
      autoLogin = {
        enable = true;
        user = "bosko";
      };
    };

    # Enable printing
    printing.enable = true;

    # Enable Qbittorrent
    qbittorrent.enable = true;
  };

  # Hardware
  hardware = {
    # Bluetooth settings
    bluetooth = {
      enable = false;
      powerOnBoot = false;
      settings.General = {
        Enable = "Source,Sink,Media,Socket";
        Experimental = true;
      };
    };

    # Enable graphical interface
    graphics.enable = true;
  };

  # Programs
  programs = {
    # Shell aliases
    zsh.shellAliases = {
      rift = "~/Rift/bin/rift";
    };
  };

  # System packages
  environment.systemPackages = with pkgs; [
    brave
    chromium
    claude-code
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
    nix-ld
    nodejs
    obs-studio
    onlyoffice-desktopeditors
    p7zip
    qalculate-qt
    tor-browser
    vesktop
    vivaldi
    vlc
  ];

  # Flatpaks
  services.flatpak.packages = [
    "com.albiononline.AlbionOnline" # Albion Online
    "org.kde.digikam" # Digikam
    "app.zen_browser.zen" # Zen Browser
  ];
}
