{ config, pkgs, ... }:

{
  # System
  system = {
    # Set NixOS Version
    stateVersion = "25.05";

    # Automatic updating
    autoUpgrade = {
      enable = true;
      dates = "daily";
      persistent = true;
    };
  };

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
    # Enable the X11 windowing system.
    xserver = {
      enable = true;

      # Configure keymap in X11
      xkb = {
        layout = "us";
        variant = "";
      };

      # Enable touchpad support (enabled default in most desktopManager).
      # libinput.enable = true;
    };

    # Enable the KDE Plasma Desktop Environment.
    desktopManager.plasma6.enable = true;

    # Enable automatic login for the user.
    displayManager = {
      autoLogin.enable = true;
      autoLogin.user = "bosko";
      sddm.enable = true;
    };

    # Enable CUPS to print documents.
    printing.enable = true;
  };

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

    # Automatic cleanup
    gc = {
      automatic = true;
      dates = "daily";
      options = "--delete-older-than 7d";
      persistent = true;
    };

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
    # If you want to use JACK applications, uncomment this
    #jack.enable = true;

    # use the example session manager (no others are packaged yet so this is enabled by default,
    # no need to redefine it in your config for now)
    #media-session.enable = true;
  };

  # Enable and configure Z shell
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestions.enable = true;
    syntaxHighlighting.enable = true;
    shellAliases = {
      ll = "ls -l";
      edit = "sudo micro";
      rebuild = "sudo nixos-rebuild switch --flake ~/NixOS/.#venom";
      update = "nix flake update --flake ~/NixOS/.";
      ".." = "cd ..";
      "/" = "cd /";
      "~" = "cd ~";
    };
    histSize = 10000;
    histFile = "$HOME/.zsh_history";
    setOptions = [ "HIST_IGNORE_ALL_DUPS" ];
    shellInit = "(cat ~/.cache/wal/sequences &)";
  };

  # Enable Starship
  programs.starship.enable = true;

  # Enable gamemode
  programs.gamemode.enable = true;

  # Enable flatpaks
  services.flatpak.enable = true;
  systemd.services.flatpak-repo = {
    path = [ pkgs.flatpak ];
    script = ''
      flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    '';
  };

  # Enable appimages
  programs.appimage = {
    enable = true;
    binfmt = true;
  };

  # Install fonts
  fonts.packages = with pkgs; [
    nerd-fonts.code-new-roman
  ];

  # Enable Steam
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true; # Open ports in the firewall for Steam Remote Play
    dedicatedServer.openFirewall = true; # Open ports in the firewall for Source Dedicated Server
    localNetworkGameTransfers.openFirewall = true; # Open ports in the firewall for Steam Local Network Game Transfers
  };

  # Enable shared libraries
  programs.nix-ld = {
    enable = true;
    libraries = with pkgs; [
      alsa-lib
      dbus
      expat
      fontconfig
      freetype
      glib
      krb5
      libGL
      nspr
      nss
      pipewire
      SDL2
      SDL2_mixer
      xorg.libX11
      xorg.libXau
      xorg.libXcomposite
      xorg.libXdamage
      xorg.libXdmcp
      xorg.libXfixes
      xorg.libXrandr
      xorg.libXrender
      xorg.libXtst
      xwayland
      wayland
    ];
  };

  # System packages to install
  environment.systemPackages = with pkgs; [
    appimage-run
    brave
    btop
    bottles
    cava
    cmatrix
    digikam
    discord
    distrobox
    docker
    fastfetch
    firefox
    flatpak
    freetube
    gamemode
    gearlever
    git
    heroic
    htop
    kitty
    lutris
    mangohud
    megasync
    mumble
    micro
    nh
    nix-index
    obs-studio
    openvpn
    php
    protontricks
    protonup-qt
    pyfa
    pywal
    starship
    tidal-hifi
    tree
    unzip
    vesktop
    vkbasalt
    vlc
    waybar
    wine
    winetricks
    wget
    zsh
  ];
}
