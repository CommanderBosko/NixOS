{ config, pkgs, system, ... }:

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

  # Set max journal entries
  services.journald.extraConfig = ''
    SystemMaxUse=500M
  '';

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

  # Enable sudo for wheel group
  security.sudo = {
    enable = true;
    wheelNeedsPassword = true;
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

  # Install fonts
  fonts.packages = with pkgs; [
    nerd-fonts.code-new-roman
  ];

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
        update = "sudo nix flake update --flake ~/NixOS/. && sudo nixos-rebuild switch --flake ~/NixOS/.#server --impure";
        cleanup = "nix-collect-garbage";
        ".." = "cd ..";
        "/" = "cd /";
        "~" = "cd ~";
      };
      histSize = 10000;
      histFile = "$HOME/.zsh_history";
      setOptions = [ "HIST_IGNORE_ALL_DUPS" ];
    };

    # Enable Starship
    starship.enable = true;
  };

  # System packages to install
  environment.systemPackages = with pkgs; [
    btop
    curl
    distrobox
    docker
    fastfetch
    git
    gnupg
    htop
    micro
    netcat
    nh
    nmap
    nix-index
    openssl
    starship
    tmux
    traceroute
    tree
    unzip
    wget
    zip
    zsh
  ];
}
