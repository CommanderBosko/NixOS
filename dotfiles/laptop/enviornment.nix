{ config, pkgs, system, username, ... }:

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
    # Enable the X11 windowing system (for XWayland support)
    xserver = {
      enable = true;

      # Keyboard layout
      xkb.layout = "us";

      # Touchpad
      libinput.enable = true;
    };

    # Display Manager (login screen)
    displayManager = {
      sddm.enable = true;
      # Make Hyprland the default session
      defaultSession = "hyprland-uwsm";
      # Auto login
      # autoLogin.enable = true;
      # autoLogin.user = username;
    };

    # Printing
    printing.enable = true;
  };

  hardware = {
    # Bluetooth
  	bluetooth = {
      enable = false;
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
      ${pkgs.flatpak}/bin/flatpak install -y --noninteractive flathub dev.aunetx.deezer
    '';
  };

  # Install fonts
  fonts.packages = with pkgs; [
    nerd-fonts.code-new-roman
  ];

  # Programs
  programs = {
    # Enable and configure Hyprland
    hyprland = {
      enable = true;
      withUWSM = true;
      xwayland.enable = true;
    };

    # Enable and configure Z shell
    zsh = {
      enable = true;
      enableCompletion = true;
      autosuggestions.enable = true;
      syntaxHighlighting.enable = true;
      shellAliases = {
        ll = "ls -l";
        edit = "sudo micro";
        update = "sudo nix flake update --flake ~/NixOS/. && sudo nixos-rebuild switch --flake ~/NixOS/.#laptop --impure && flatpak update -y && flatpak remove --unused --noninteractive";
        cleanup = "nix-collect-garbage";
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
    starship.enable = true;

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
    gpt4all
    htop
    hyprland
    kitty
    lutris
    mangohud
    megacmd
    micro
    nh
    nm-tray
    nix-index
    onlyoffice-bin
    openvpn
    protontricks
    protonup-qt
    pywal
    rofi
    starship
    swww
    tree
    unzip
    vesktop
    vkbasalt
    vlc
    vscode
    waybar
    wget
    zsh
  ];
}
