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
    # Zsh
    zsh = {
      enable = true;
      enableCompletion = true;
      autosuggestions.enable = true;
      syntaxHighlighting.enable = true;

      histSize = 10000;
      histFile = "$HOME/.zsh_history";
      setOptions = [ "HIST_IGNORE_ALL_DUPS" ];

      shellAliases = {
        la = "ls -a";
        ll = "ls -l";
        lla = "ls -la";
        edit = "sudo micro";
        update = ''
        echo ""
        echo "Updating your system"
        echo ""
        sudo nix flake update --flake ~/NixOS/.
        echo ""
        echo "Updating Flatpaks"
        flatpak update -y
        echo ""
        sudo nixos-rebuild switch --flake ~/NixOS/.#${hostname} --impure
        '';
        cleanup = ''
        nh clean all --keep 5
        echo ""
        echo "Removing unused Flatpaks"
        flatpak remove --unused --noninteractive
        '';
        rift = "~/Rift/bin/rift";
        albion = "~/Games/albion-online/data/Albion-Online";
        ".." = "cd ..";
        "/" = "cd /";
        "~" = "cd ~";
      };

      # Pywal initation or not if no pywal cache generated
      shellInit = ''
        if [[ $- == *i* && -f ~/.cache/wal/sequences ]]; then
          (cat ~/.cache/wal/sequences &)
        fi
      '';
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
    btop
    cava
    cmatrix
    curl
    deezer-enhanced
    distrobox
    docker
    fastfetch
    faugus-launcher
    flatpak
    freetube
    gamemode
    gearlever
    git
    gparted
    heroic
    htop
    kdePackages.kate
    kitty
    lutris
    mangohud
    mangojuice
    megasync
    micro
    mumble
    nh
    nix-health
    nix-index
    nix-init
    nix-tree
    obs-studio
    onlyoffice-desktopeditors
    p7zip
    php
    pipes
    protontricks
    protonup-qt
    pywal
    qalculate-qt
    r2modman
    starship
    tree
    tty-clock
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
    xorg.xprop
    xorg.xwininfo
    yazi
    zip
    zsh
  ];
}
