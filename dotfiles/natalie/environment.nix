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

    # Pipewire
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
        sudo nixos-rebuild switch --flake ~/NixOS/.#natalie --impure
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
