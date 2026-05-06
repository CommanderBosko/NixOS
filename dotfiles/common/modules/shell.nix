{ config, pkgs, ... }:

let
  hostName = config.networking.hostName;
in
{
  # Configure shell programs
  programs = {
    # Customize zsh
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
        ls = "eza";
        la = "eza -a";
        ll = "eza -l";
        lla = "eza -la";
        edit = "sudo hx";
        shell = "nix-shell -p";
        cleanup = ''
          echo ""
          echo "Cleaning up your system"
          echo ""
          nh clean all --keep 5
          echo ""
          echo "Removing unused Flatpaks"
          echo ""
          flatpak remove --unused --noninteractive
        '';
        dry-run = ''
          echo ""
          echo "Attempting a dry-run on your system"
          echo ""
          nixos-rebuild dry-run --flake ~/NixOS/.#${hostName}
        '';
        rebuild = ''
          echo ""
          echo "Rebuilding your system"
          echo ""
          nh os switch ~/NixOS/. -H ${hostName}
        '';
        update = ''
          echo ""
          echo "Updating your flake"
          echo ""
          nix flake update --flake ~/NixOS/.
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

    # Direnv
    direnv = {
      enable = true;
      nix-direnv.enable = true;
    };

    # Zoxide
    zoxide = {
      enable = true;
      enableZshIntegration = true;
    };
  };

  environment = {
    # Set default editor to micro
    variables = {
      EDITOR = "hx";
      VISUAL = "hx";
    };

    # Shell packages
    systemPackages = with pkgs; [
      btop
      cava
      cmatrix
      comma
      curl
      eza
      fastfetch
      fzf
      git
      helix
      htop
      lm_sensors
      micro
      nh
      nil
      nix-health
      nix-index
      nix-init
      nix-tree
      nixd
      nixfmt
      pipes
      pywal
      starship
      tree
      tty-clock
      unzip
      wget
      yazi
      zip
      zoxide
      zsh
    ];
  };
}
