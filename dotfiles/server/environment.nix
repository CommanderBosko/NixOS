{ config, pkgs, system, ... }:

{
  # System
  system = {
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

  # Enable sudo for wheel group
  security.sudo = {
    enable = true;
    wheelNeedsPassword = true;
  };

  # Automatic cleanup
  nix.gc = {
    automatic = true;
    dates = "daily";
    options = "--delete-older-than 7d";
    persistent = true;
  };

  # Enable Starship
  programs.starship.enable = true;
  system.activationScripts.starship = {
    text = ''
      mkdir -p ~/.config
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
        lla = "ls -la";
        edit = "sudo micro";
        update = ''
        echo ""
        echo "Updating your system"
        echo ""
        sudo nix flake update --flake ~/NixOS/.
        echo ""
        sudo nixos-rebuild switch --flake ~/NixOS/.#server --impure
        '';
        cleanup = "nh clean all --keep 5";
        ".." = "cd ..";
        "/" = "cd /";
        "~" = "cd ~";
      };
      histSize = 10000;
      histFile = "$HOME/.zsh_history";
      setOptions = [ "HIST_IGNORE_ALL_DUPS" ];
    };
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
    nix-health
    nix-tree
    nmap
    openssl
    starship
    tmux
    traceroute
    tree
    unzip
    wget
    yazi
    zip
    zsh
  ];
}
