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
    desktopManager.cosmic.enable = true;

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

  # Flatpak: Flathub Repository
  system.activationScripts.flathub.text = ''
    ${pkgs.flatpak}/bin/flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
  '';

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
    mkdir -p /home/natty/.config
    cp /home/natty/NixOS/dotfiles/common/starship.toml /home/natty/.config/starship.toml
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
        update = "sudo nix flake update --flake ~/NixOS/. && flatpak update -y && sudo nixos-rebuild switch --flake ~/NixOS/.#natalie --impure";
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
  };

  # System Packages
  environment.systemPackages = with pkgs; [
    appimage-run
    brave
    btop
    bottles
    curl
    deezer-enhanced
    discord
    fastfetch
    firefox
    flatpak
    freetube
    gamemode
    gearlever
    gimp
    git
    htop
    kdePackages.kate
    kdePackages.kdenlive
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
    starship
    tree
    unzip
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
