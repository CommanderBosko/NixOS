{ config, pkgs, ... }:

{
  # Set NixOS Version
  system.stateVersion = "25.05";

  # Set your time zone.
  time.timeZone = "America/New_York";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
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

  # Enable the X11 windowing system.
  # You can disable this if you're only using the Wayland session.
  services.xserver.enable = true;

  # Enable the KDE Plasma Desktop Environment.
  services.displayManager.sddm.enable = true;
  services.desktopManager.plasma6.enable = true;

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # Enable Bluetooth
  hardware.bluetooth.enable = true;

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable flakes
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Enable OpenGL
  hardware.graphics.enable = true;

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

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  # Enable automatic login for the user.
  services.displayManager.autoLogin.enable = true;
  services.displayManager.autoLogin.user = "bosko";

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # Automatic updating
  system.autoUpgrade = {
    enable = true;
    dates = "daily";
    persistent = true;
  };

  # Automatic cleanup
  nix.gc = {
    automatic = true;
    dates = "daily";
    options = "--delete-older-than 7d";
    persistent = true;
  };

  # Optimise store on rebuild
  nix.settings.auto-optimise-store = true;

  # Enable and configure Z shell
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestions.enable = true;
    syntaxHighlighting.enable = true;
    shellAliases = {
      ll = "ls -l";
      edit = "sudo micro";
      update = "sudo nixos-rebuild switch";
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
