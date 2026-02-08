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
      powerOnBoot = true;
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
    btop
    bottles
    curl
    deezer-enhanced
    fastfetch
    flatpak
    freetube
    gamemode
    gearlever
    gimp
    git
    htop
    kdePackages.kate
    kitty
    megasync
    micro
    nh
    nix-health
    nix-index
    nix-init
    nix-tree
    onlyoffice-desktopeditors
    p7zip
    protontricks
    protonup-qt
    pywal
    qalculate-qt
    starship
    tree
    unzip
    vesktop
    vivaldi
    vkbasalt
    vlc
    vulkan-tools
    wine
    winetricks
    wget
    wmctrl
    yazi
    zip
    zsh
  ];
}
