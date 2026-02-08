{ config, pkgs, system, ... }:

{
  # Services
  services = {
    # Desktop Environment
    desktopManager = {
      plasma6.enable = true;
      cosmic.enable = true;
    };

    # Display Manager
    displayManager = {
      sddm = {
        enable = true;
        wayland.enable = true;
        autoNumlock = true;
      };

      defaultSession = "cosmic";
    };

    # Input
    libinput.enable = true;

    # Printing
    printing.enable = true;

    # Flatpak
    flatpak.enable = true;
  };

  # Hardware
  hardware = {
    bluetooth = {
      enable = true;
      powerOnBoot = false;
      settings.General = {
        Enable = "Source,Sink,Media,Socket";
        Experimental = true;
      };
    };

    graphics.enable = true;
  };

  # Starship
  programs.starship.enable = true;
  system.activationScripts.starship.text = ''
    mkdir -p /home/natty/.config
    cp /home/natty/NixOS/dotfiles/common/starship.toml /home/natty/.config/starship.toml
  '';

  # Kitty terminal
  system.activationScripts.kitty.text = ''
    mkdir -p /home/natty/.config/kitty
    cp /home/natty/NixOS/dotfiles/common/kitty.conf /home/natty/.config/kitty/kitty.conf
  '';

  # Programs
  programs = {
    # Xwayland
    xwayland.enable = true;

    # AppImage support
    appimage = {
      enable = true;
      binfmt = true;
    };
  };

  # System Packages
  environment.systemPackages = with pkgs; [
    appimage-run
    brave
    bottles
    chromium
    deezer-enhanced
    flatpak
    freetube
    gearlever
    gimp
    kdePackages.kate
    kitty
    megasync
    onlyoffice-desktopeditors
    p7zip
    qalculate-qt
    starship
    vesktop
    vivaldi
    vlc
  ];
}
