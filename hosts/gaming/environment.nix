{ pkgs, ... }:

{
  # Services
  services = {
    # Display manager settings
    displayManager = {
      autoLogin.enable = false;
    };

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

  # Enable aarch64 emulation so this machine can build for vpn-server (Oracle ARM)
  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];
  nix.settings.extra-platforms = [ "aarch64-linux" ];

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
    element-desktop
    firefox
    freetube
    github-desktop
    gparted
    kdePackages.kate
    kitty
    megasync
    mumble
    nodejs
    obs-studio
    onlyoffice-desktopeditors
    p7zip
    pnpm
    qalculate-qt
    tmux
    tor-browser
    vesktop
    vlc
  ];

  # Flatpaks
  services.flatpak.packages = [
    "com.albiononline.AlbionOnline" # Albion Online
    "dev.aunetx.deezer" # Deezer
    "org.kde.digikam" # Digikam
    "app.zen_browser.zen" # Zen Browser
  ];
}
