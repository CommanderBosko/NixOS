{ config, pkgs, system, ... }:

{
  # Time zone
  time.timeZone = "America/New_York";

  # Internationalisation
  i18n = {
    defaultLocale = "en_US.UTF-8";
    extraLocaleSettings = {
      LC_ADDRESS = "en_US.UTF-8";
      LC_IDENTIFICATION = "en_US.UTF-8";
      LC_MEASUREMENT = "en_US.UTF-8";
      LC_MONETARY = "en_US.UTF-8";
      LC_NAME = "en_US.UTF-8";
      LC_NUMERIC = "en_US.UTF-8";
      LC_PAPER = "en_US.UTF-8";
      LC_TELEPHONE = "en_US.UTF-8";
      LC_TIME = "en_US.UTF-8";
    };
  };

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

    # Pipewire (replaces PulseAudio)
    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
    };

    # Firmware updates
    fwupd = {
      enable = true;
      daemonSettings = {
        EspLocation = "/boot";
      };
    };
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

  # Nixpkgs
  nixpkgs.config.allowUnfree = true;

  # Nix settings
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    auto-optimise-store = true;
    download-buffer-size = 1024 * 1024 * 1024; #1 GB
  };

  # Audio
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;

  # Fonts
  fonts.packages = with pkgs; [
    font-awesome
    nerd-fonts.code-new-roman
    noto-fonts
    noto-fonts-cjk-sans
  ];

  # Starship
  programs.starship.enable = true;
  system.activationScripts.starship.text = ''
    mkdir -p /home/bosko/.config
    cp /home/bosko/NixOS/dotfiles/common/starship.toml /home/bosko/.config/starship.toml
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
        sudo nixos-rebuild switch --flake ~/NixOS/.#gaming --impure
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

      shellInit = ''
        if [[ $- == *i* && -f ~/.cache/wal/sequences ]]; then
          (cat ~/.cache/wal/sequences &)
        fi
      '';
    };

    # AppImage support
    appimage = {
      enable = true;
      binfmt = true;
    };

    # Steam
    steam = {
      enable = true;
      remotePlay.openFirewall = true;
      dedicatedServer.openFirewall = true;
      localNetworkGameTransfers.openFirewall = true;
    };

    # Gamemode
    gamemode.enable = true;

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
