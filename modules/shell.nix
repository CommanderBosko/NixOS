{ config, pkgs, hostsData, ... }:

let
  hostName = config.networking.hostName;
  vpnServer = hostsData.hosts.vpn-server.ip;
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
        # Common aliases
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
          nh clean all --keep 3
          echo ""
          echo "Removing unused Flatpaks"
          echo ""
          sudo flatpak remove --unused --noninteractive
        '';
        dry-run = ''
          echo ""
          echo "Attempting a dry-run on your system"
          echo ""
          nh os boot ~/NixOS/. -H ${hostName} --dry
        '';
        rebuild-boot = ''
          echo ""
          echo "Rebuilding your system"
          echo ""
          nh os boot ~/NixOS/. -H ${hostName}
        '';
        rebuild-switch = ''
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

        # vpn-server management aliases (address comes from .claude/hosts.json).
        # vpn-on/vpn-off live in vpn.nix beside the wg0 unit they control.
        vpn-dry-run = ''
          echo ""
          echo "Attempting a dry-run on vpn-server"
          echo ""
          nixos-rebuild dry-activate --flake /home/bosko/NixOS#vpn-server --target-host bosko@${vpnServer} --build-host bosko@${vpnServer} --use-remote-sudo
        '';
        vpn-logs   = "ssh bosko@${vpnServer} 'sudo journalctl -u wg-quick-wg0 -n 50 --no-pager'";
        vpn-rebuild = ''
          echo ""
          echo "Rebuilding vpn-server"
          echo ""
          nixos-rebuild switch --flake /home/bosko/NixOS#vpn-server --target-host bosko@${vpnServer} --build-host bosko@${vpnServer} --use-remote-sudo
        '';
        vpn-ssh    = "ssh bosko@${vpnServer}";
        vpn-status = "ssh bosko@${vpnServer} 'sudo wg show'";
        vpn-watch  = "watch -n 5 ssh bosko@${vpnServer} sudo wg show";
      };

      # Source Home Manager session variables (sessionPath, sessionVariables) for
      # non-login shells. HM writes these to ~/.nix-profile/etc/profile.d/hm-session-vars.sh
      # but that file is only sourced by login shells unless we explicitly include it here.
      shellInit = ''
        if [ -f "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh" ]; then
          . "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh"
        fi

        # Pywal initation or not if no pywal cache generated
        if [[ $- == *i* && -f ~/.cache/wal/sequences ]]; then
          (cat ~/.cache/wal/sequences &)
        fi
      '';
    };

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
    # Default editor: helix
    variables = {
      EDITOR = "hx";
      VISUAL = "hx";
    };

    # CLI essentials for every host. Dev toolchains live in development.nix and
    # desktop-only tools in desktop-apps.nix; zoxide/zsh come from their
    # programs.* options, starship from starship.nix.
    systemPackages = with pkgs; [
      btop
      comma
      curl
      eza
      fastfetch
      fzf
      gh
      git
      helix
      htop
      jq
      lm_sensors
      micro
      nh
      nix-health
      nix-index
      nix-tree
      p7zip
      tree
      unzip
      wget
      yazi
      zip
    ];
  };
}
