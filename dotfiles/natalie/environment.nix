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

  # Starship
  programs.starship.enable = true;
  system.activationScripts.starship.text = ''
    mkdir -p /home/natty/.config
    cp /home/natty/NixOS/dotfiles/common/configs/starship.toml /home/natty/.config/starship.toml
  '';

  # Kitty terminal
  system.activationScripts.kitty.text = ''
    mkdir -p /home/natty/.config/kitty
    cp /home/natty/NixOS/dotfiles/common/configs/kitty.conf /home/natty/.config/kitty/kitty.conf
  '';

  # System packages
  environment.systemPackages = with pkgs; [
    brave
    chromium
    deezer-enhanced
    freetube
    gimp
    gparted
    kdePackages.kate
    kitty
#     megasync
    onlyoffice-desktopeditors
    p7zip
    qalculate-qt
    starship
    vesktop
    vivaldi
    vlc
  ];
}
