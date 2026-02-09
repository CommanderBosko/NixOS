{ config, pkgs, ... }:

let
  hostName = config.networking.hostName;
in
{
  # Customize zsh
  programs = {
    zsh = {
      enable = true;
      enableCompletion = true;
      autosuggestions.enable = true;
      syntaxHighlighting.enable = true;

      histSize = 10000;
      histFile = "$HOME/.zsh_history";
      setOptions = [ "HIST_IGNORE_ALL_DUPS" ];

      shellAliases = {
        ".." = "cd ..";
        "/" = "cd /";
        "~" = "cd ~";
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
          sudo nixos-rebuild switch --flake ~/NixOS/.#${hostName} --impure
        '';
        cleanup = ''
          nh clean all --keep 5
          echo ""
          echo "Removing unused Flatpaks"
          flatpak remove --unused --noninteractive
        '';
      };

      # Pywal initation or not if no pywal cache generated
      shellInit = ''
        if [[ $- == *i* && -f ~/.cache/wal/sequences ]]; then
          (cat ~/.cache/wal/sequences &)
        fi
      '';
    };

    # Starship
    starship.enable = true;
  };

  # Shell packages
  environment.systemPackages = with pkgs; [
    btop
    cava
    cmatrix
    curl
    distrobox
    docker
    fastfetch
    git
    htop
    lm_sensors
    micro
    nh
    nix-health
    nix-index
    nix-init
    nix-tree
    php
    pipes
    pywal
    starship
    tree
    tty-clock
    unzip
    wget
    yazi
    zip
    zsh
  ];
}
