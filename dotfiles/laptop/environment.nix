{ config, pkgs, system, ... }:

{
  # Services
  services = {
    # Desktop Environments
    desktopManager = {
      plasma6.enable = true;
      cosmic.enable = true;
    };

    # Display Manager
    displayManager = {
      sddm = {
        enable = true;
        theme = "breeze";
        wayland.enable = true;
        autoNumlock = true;
      };

      # Default DE session
      defaultSession = "cosmic";
    };

    # Enable touchpad
    libinput.enable = true;

    # Enable printing
    printing.enable = true;

    # Enable xserver
    xserver.enable = true;
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
    deezer-enhanced
    discord
    firefox
    freetube
    gparted
    kdePackages.kate
    kitty
    megasync
    obs-studio
    onlyoffice-desktopeditors
    p7zip
    qalculate-qt
    rpi-imager
    vesktop
    vivaldi
    vlc
  ];

  # Flatpaks
  services.flatpak.packages = [
      "org.kde.digikam" # Digikam
      "com.github.tchx84.Flatseal" # Flatseal
    ];
}
