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
        sudo nixos-rebuild switch --flake ~/NixOS/.#laptop --impure
        '';
        cleanup = ''
        nh clean all --keep 5
        echo ""
		echo "Removing unused Flatpaks"
        flatpak remove --unused --noninteractive
        '';
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
    flatpak
    freetube
    gamemode
    gearlever
    git
    gparted
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
    php
    pipes
    protontricks
    protonup-qt
    pywal
    qalculate-qt
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
