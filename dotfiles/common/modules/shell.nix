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
          echo ""
          echo "Cleaning up your system"
          echo ""
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
        rebuild = ''
          echo ""
          echo "Rebuilding your system"
          echo ""
          nh os boot ~/NixOS/. -H ${hostName}
        '';
        update = ''
          echo ""
          echo "Updating your flake"
          echo ""
          nix flake update --flake ~/NixOS/.
        '';

        # VPN aliases
        vpn-dry-run = ''
          echo ""
          echo "Attempting a dry-run on vpn-server"
          echo ""
          nixos-rebuild dry-activate --flake /home/bosko/NixOS#vpn-server --target-host root@150.136.232.63 --build-host root@150.136.232.63
        '';
        vpn-logs   = "ssh root@150.136.232.63 'journalctl -u wg-quick@wg0 -n 50 --no-pager'";
        vpn-rebuild = ''
          echo ""
          echo "Rebuilding vpn-server"
          echo ""
          nixos-rebuild switch --flake /home/bosko/NixOS#vpn-server --target-host root@150.136.232.63 --build-host root@150.136.232.63
        '';
        vpn-off    = "sudo systemctl stop wg-quick-wg0";
        vpn-on     = "sudo systemctl start wg-quick-wg0";
        vpn-ssh    = "ssh root@150.136.232.63";
        vpn-status = "ssh root@150.136.232.63 'wg show'";
        vpn-watch  = "watch -n 5 ssh root@150.136.232.63 wg show";
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

    # Starship
    starship = {
      enable = true;
      settings = {
        "$schema" = "https://starship.rs/config-schema.json";

        format =
          "[](color_orange)"
          + "$os"
          + "$username"
          + "[](bg:color_yellow fg:color_orange)"
          + "$directory"
          + "[](fg:color_yellow bg:color_aqua)"
          + "$git_branch"
          + "$git_status"
          + "[](fg:color_aqua bg:color_blue)"
          + "$c"
          + "$rust"
          + "$golang"
          + "$nodejs"
          + "$php"
          + "$java"
          + "$kotlin"
          + "$haskell"
          + "$python"
          + "[](fg:color_blue bg:color_bg3)"
          + "$docker_context"
          + "$conda"
          + "[](fg:color_bg3 bg:color_bg1)"
          + "$time"
          + "[ ](fg:color_bg1)"
          + "$line_break$character";

        palette = "gruvbox_dark";

        palettes.gruvbox_dark = {
          color_fg0 = "#fbf1c7";
          color_bg1 = "#3c3836";
          color_bg3 = "#665c54";
          color_blue = "#458588";
          color_aqua = "#689d6a";
          color_green = "#98971a";
          color_orange = "#d65d0e";
          color_purple = "#b16286";
          color_red = "#cc241d";
          color_yellow = "#d79921";
        };

        os = {
          disabled = false;
          style = "bg:color_orange fg:color_fg0";
          symbols = {
            Windows = "󰍲";
            Ubuntu = "󰕈";
            SUSE = "";
            Raspbian = "󰐿";
            Mint = "󰣭";
            Macos = "󰀵";
            Manjaro = "";
            Linux = "󰌽";
            Gentoo = "󰣨";
            Fedora = "󰣛";
            Alpine = "";
            Amazon = "";
            Android = "";
            Arch = "󰣇";
            Artix = "󰣇";
            CentOS = "";
            Debian = "󰣚";
            Redhat = "󱄛";
            RedHatEnterprise = "󱄛";
          };
        };

        username = {
          show_always = true;
          style_user = "bg:color_orange fg:color_fg0";
          style_root = "bg:color_orange fg:color_fg0";
          format = "[ $user ]($style)";
        };

        directory = {
          style = "fg:color_fg0 bg:color_yellow";
          format = "[ $path ]($style)";
          truncation_length = 0;
          truncation_symbol = "…/";
          substitutions = {
            "Documents" = "󰈙 ";
            "Downloads" = " ";
            "Music" = "󰝚 ";
            "Pictures" = " ";
            "Developer" = "󰲋 ";
          };
        };

        git_branch = {
          symbol = " ";
          style = "bg:color_aqua";
          format = "[[ $symbol $branch ](fg:color_fg0 bg:color_aqua)]($style)";
        };

        git_status = {
          style = "bg:color_aqua";
          format = "[[($all_status$ahead_behind )](fg:color_fg0 bg:color_aqua)]($style)";
        };

        nodejs = {
          symbol = " ";
          style = "bg:color_blue";
          format = "[[ $symbol( $version) ](fg:color_fg0 bg:color_blue)]($style)";
        };

        c = {
          symbol = " ";
          style = "bg:color_blue";
          format = "[[ $symbol( $version) ](fg:color_fg0 bg:color_blue)]($style)";
        };

        rust = {
          symbol = " ";
          style = "bg:color_blue";
          format = "[[ $symbol( $version) ](fg:color_fg0 bg:color_blue)]($style)";
        };

        golang = {
          symbol = " ";
          style = "bg:color_blue";
          format = "[[ $symbol( $version) ](fg:color_fg0 bg:color_blue)]($style)";
        };

        php = {
          symbol = " ";
          style = "bg:color_blue";
          format = "[[ $symbol( $version) ](fg:color_fg0 bg:color_blue)]($style)";
        };

        java = {
          symbol = " ";
          style = "bg:color_blue";
          format = "[[ $symbol( $version) ](fg:color_fg0 bg:color_blue)]($style)";
        };

        kotlin = {
          symbol = " ";
          style = "bg:color_blue";
          format = "[[ $symbol( $version) ](fg:color_fg0 bg:color_blue)]($style)";
        };

        haskell = {
          symbol = " ";
          style = "bg:color_blue";
          format = "[[ $symbol( $version) ](fg:color_fg0 bg:color_blue)]($style)";
        };

        python = {
          symbol = " ";
          style = "bg:color_blue";
          format = "[[ $symbol( $version) ](fg:color_fg0 bg:color_blue)]($style)";
        };

        docker_context = {
          symbol = " ";
          style = "bg:color_bg3";
          format = "[[ $symbol( $context) ](fg:#83a598 bg:color_bg3)]($style)";
        };

        conda = {
          style = "bg:color_bg3";
          format = "[[ $symbol( $environment) ](fg:#83a598 bg:color_bg3)]($style)";
        };

        time = {
          disabled = false;
          time_format = "%R";
          style = "bg:color_bg1";
          format = "[[  $time ](fg:color_fg0 bg:color_bg1)]($style)";
        };

        line_break.disabled = false;

        character = {
          disabled = false;
          success_symbol = "[](bold fg:color_blue)";
          error_symbol = "[](bold fg:color_red)";
          vimcmd_symbol = "[](bold fg:color_green)";
          vimcmd_replace_one_symbol = "[](bold fg:color_purple)";
          vimcmd_replace_symbol = "[](bold fg:color_purple)";
          vimcmd_visual_symbol = "[](bold fg:color_yellow)";
        };
      };
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
    # Set default editor to micro
    variables = {
      EDITOR = "hx";
      VISUAL = "hx";
      LIBVIRT_DEFAULT_URI = "qemu:///system";
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
      gh
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
      qdirstat
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
