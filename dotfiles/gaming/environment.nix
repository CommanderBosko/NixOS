{ config, pkgs, system, ... }:

{
  # Set your time zone.
  time.timeZone = "America/New_York";

  # Select internationalisation properties.
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
    # Choose DE/WM
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

    # Enable CUPS
    printing.enable = true;
  };

  # Configure hardware
  hardware = {
    # Bluetooth
  	bluetooth = {
      enable = true;
	  powerOnBoot = true;
	  settings = {
	    General = {
	      Enable = "Source,Sink,Media,Socket";
	      Experimental = true;
	    };
      };
    };

    # Enable OpenGL
    graphics.enable = true;
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # Nix settings
  nix = {
    # Enable flakes
    settings.experimental-features = [ "nix-command" "flakes" ];

    # Optimise store on rebuild
    settings.auto-optimise-store = true;
  };

  # Enable sound with pipewire.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    #jack.enable = true;
    #media-session.enable = true;
  };

  # Flatpaks
  services.flatpak.enable = true;
  # Flathub repo
  system.activationScripts.flathub = {
    text = ''
      ${pkgs.flatpak}/bin/flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    '';
  };
  # Install scripts at launch
  system.activationScripts.flatpakApps = {
    text = ''
      ${pkgs.flatpak}/bin/flatpak install -y --noninteractive flathub com.github.tchx84.Flatseal
      ${pkgs.flatpak}/bin/flatpak install -y --noninteractive flathub com.discordapp.Discord
    '';
  };

  # Install fonts
  fonts.packages = with pkgs; [
    nerd-fonts.code-new-roman
    noto-fonts
    noto-fonts-cjk-sans
    font-awesome
  ];

  # Enable Starship
  programs.starship.enable = true;
  system.activationScripts.starship = {
    text = ''
      mkdir -p /home/bosko/.config
      cp /home/bosko/NixOS/dotfiles/common/starship.toml /home/bosko/.config/starship.toml
    '';
  };

  # Programs
  programs = {
    # Enable and configure Z shell
    zsh = {
      enable = true;
      enableCompletion = true;
      autosuggestions.enable = true;
      syntaxHighlighting.enable = true;
      shellAliases = {
        la = "ls -a";
        ll = "ls -l";
        edit = "sudo micro";
        update = "sudo nix flake update --flake ~/NixOS/. && flatpak update -y && flatpak remove --unused --noninteractive && sudo nixos-rebuild switch --flake ~/NixOS/.#gaming --impure";
        cleanup = "nh clean all --keep 5";
        rift = "~/Rift/bin/rift";
        ".." = "cd ..";
        "/" = "cd /";
        "~" = "cd ~";
      };
      histSize = 10000;
      histFile = "$HOME/.zsh_history";
      setOptions = [ "HIST_IGNORE_ALL_DUPS" ];
      # Enable pywal and ignore non-interactive shells
      shellInit = ''
        if [[ $- == *i* && -f ~/.cache/wal/sequences ]]; then
          (cat ~/.cache/wal/sequences &)
        fi
      '';
    };

    # Enable appimages
    appimage = {
      enable = true;
      binfmt = true;
    };

    # Enable Steam
    steam = {
      enable = true;
      remotePlay.openFirewall = true; # Open ports in the firewall for Steam Remote Play
      dedicatedServer.openFirewall = true; # Open ports in the firewall for Source Dedicated Server
      localNetworkGameTransfers.openFirewall = true; # Open ports in the firewall for Steam Local Network Game Transfers
    };

    # Enable gamemode
    gamemode.enable = true;

    # Enable shared libraries
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
        libusb1
        libpulseaudio
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
        wayland
        zlib
        zulu
      ];
    };
  };

  # System packages to install
  environment.systemPackages = with pkgs; [
    appimage-run
    brave
    btop
    bottles
    cava
    cmatrix
    curl
    deezer-enhanced
#     digikam
    distrobox
    docker
    fastfetch
    firefox
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
    mumble
    micro
    nh
    nix-health
    nix-index
    nix-init
    nix-tree
    obs-studio
    onlyoffice-desktopeditors
    p7zip
    pipes
    php
    protontricks
    protonup-qt
    pyfa
    pywal
    r2modman
    starship
    tree
    tty-clock
    unzip
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
