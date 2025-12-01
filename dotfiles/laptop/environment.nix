{ config, pkgs, system, ... }:

{
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
    desktopManager = {
      plasma6.enable = true;
      cosmic.enable = true;
    };

    # Display Manager
    displayManager.sddm = {
      enable = true;
      wayland.enable = true;
      autoNumlock = true;
    };

    # Input
    libinput.enable = true;

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
        update = "sudo nix flake update --flake ~/NixOS/. && flatpak update -y && sudo nixos-rebuild switch --flake ~/NixOS/.#laptop --impure";
        cleanup = "nh clean all --keep 5 && flatpak remove --unused --noninteractive";
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

    # Niri
    niri.enable = true;
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
    discord
    distrobox
    docker
    fastfetch
    firefox
    flatpak
    freetube
    fuzzel
    gamemode
    gearlever
    git
    gparted
    htop
    kdePackages.kate
    kitty
    mangohud
    mangojuice
    megasync
    micro
    nh
    niri
    nix-health
    nix-index
    nix-init
    nix-tree
    onlyoffice-desktopeditors
    p7zip
    php
    pipes
    protontricks
    protonup-qt
    pywal
    starship
    tree
    tty-clock
    unzip
    vivaldi
    vkbasalt
    vlc
    vulkan-tools
    waybar
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
