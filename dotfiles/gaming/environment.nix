{ config, pkgs, system, ... }:

{
  # Services
  services = {
    # Desktop Environment
    desktopManager.plasma6.enable = true;

    # Display Manager
    displayManager = {
      autoLogin = {
        enable = true;
        user = "bosko";
      };

      sddm = {
        enable = true;
        wayland.enable = true;
        autoNumlock = true;
      };
    };

    # Printing
    printing.enable = true;

    # Flatpak
    flatpak.enable = true;
  };

  # Hardware
  hardware = {
    bluetooth = {
      enable = false;
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
    mkdir -p /home/bosko/.config
    cp /home/bosko/NixOS/dotfiles/common/starship.toml /home/bosko/.config/starship.toml
  '';

  # Kitty terminal
  system.activationScripts.kitty.text = ''
    mkdir -p /home/bosko/.config/kitty
    cp /home/bosko/NixOS/dotfiles/common/kitty.conf /home/bosko/.config/kitty/kitty.conf
  '';

  # Programs
  programs = {
    # Shell aliases
    zsh.shellAliases = {
        rift = "~/Rift/bin/rift";
        albion = "~/Games/albion-online/data/Albion-Online";
      };

    # Xwayland
    xwayland.enable = true;

    # AppImage support
    appimage = {
      enable = true;
      binfmt = true;
    };

    # Dynamic library loader (nix-ld)
    nix-ld = {
      enable = true;
      libraries = with pkgs; [
        alsa-lib
        atk
        cairo
        dbus
        expat
        fontconfig
        freetype
        gdk-pixbuf
        glib
        gtk2
        gtk3
        krb5
        libdrm
        libGL
        libpulseaudio
        libusb1
        libva
        libvdpau
        mesa
        nspr
        nss
        pango
        pipewire
        SDL2
        SDL2_mixer
        udev
        vulkan-loader
        wayland
        xorg.libX11
        xorg.libXau
        xorg.libXcomposite
        xorg.libXcursor
        xorg.libXdamage
        xorg.libXdmcp
        xorg.libXext
        xorg.libXfixes
        xorg.libXi
        xorg.libICE
        xorg.libXinerama
        xorg.libXrandr
        xorg.libXrender
        xorg.libSM
        xorg.libXtst
        xorg.libXt
        xwayland
        zlib
        zulu
      ];
    };
  };

  # System Packages
  environment.systemPackages = with pkgs; [
    appimage-run
    bottles
    brave
    deezer-enhanced
    flatpak
    freetube
    gearlever
    gparted
    kdePackages.kate
    kitty
    megasync
    mumble
    obs-studio
    onlyoffice-desktopeditors
    p7zip
    qalculate-qt
    starship
    vesktop
    vivaldi
    vlc
  ];
}
