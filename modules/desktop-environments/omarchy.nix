{ pkgs, ... }:

{
  # Enable Hyprland (Omarchy's compositor). Independent of hyprland.nix by
  # design — Omarchy's own shell is Waybar + Hyprlock + Walker, a completely
  # different stack from the DMS integration hyprland.nix wires up, so this
  # module is self-contained rather than layering on top of it.
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
    package = pkgs.hyprland;
  };

  environment.systemPackages = with pkgs; [
    grim # Screenshot utility
    slurp # Region selection for grim
    wl-clipboard # Wayland clipboard utilities
    wlr-randr # RandR utility for Wayland
    playerctl # MPRIS media control
    xdg-desktop-portal-hyprland
  ];

  # Home Manager: Omarchy-style shell (Waybar status bar, Hyprlock screen
  # locker, Walker app launcher — Omarchy's actual defaults, confirmed via
  # /research), themed in Omarchy's default Tokyo Night palette, with a
  # keyboard-driven Hyprland config mirroring Omarchy's keybind philosophy
  # (Super+Return terminal, Super+Space launcher, Super+<n> workspaces).
  # Scoped to theme + keybind philosophy only — this repo's existing app
  # choices (kitty, dolphin) are kept rather than swapping in Omarchy's own
  # picks (Alacritty, etc.). Known gap: dolphin has no Qt/KDE theming glue
  # here (unlike niri.nix/hyprland.nix's qt6ct+kdeglobals setup, which is
  # coupled to DMS's matugen color generation and doesn't apply without DMS
  # running) — it will render in Qt's default light style.
  home-manager.users.bosko = { pkgs, ... }: {
    wayland.windowManager.hyprland = {
      enable = true;
      # Pinned explicitly: home-manager's default is migrating toward a Lua
      # config format, but the `settings` attrset below follows the classic
      # hyprlang schema — this keeps that working regardless of future
      # stateVersion/nixpkgs default changes.
      configType = "hyprlang";
      settings = {
        "$mod" = "SUPER";
        "$terminal" = "kitty";
        "$fileManager" = "dolphin";
        "$menu" = "walker";

        monitor = [ ",preferred,auto,auto" ];

        exec-once = [ "waybar" "hypridle" ];

        general = {
          gaps_in = 4;
          gaps_out = 8;
          border_size = 2;
          "col.active_border" = "rgba(7aa2f7ff)"; # Tokyo Night blue
          "col.inactive_border" = "rgba(1a1b26aa)"; # Tokyo Night background
          layout = "dwindle";
        };

        decoration = {
          rounding = 8;
          blur = {
            enabled = true;
            size = 4;
            passes = 2;
          };
        };

        input = {
          kb_layout = "us";
          follow_mouse = 1;
          touchpad.natural_scroll = true;
        };

        bind =
          [
            "$mod, Return, exec, $terminal"
            "$mod, Space, exec, $menu"
            "$mod, E, exec, $fileManager"
            "$mod, Q, killactive"
            "$mod, M, exit"
            "$mod, V, togglefloating"
            "$mod, F, fullscreen"
          ]
          ++ (map (i: "$mod, ${toString i}, workspace, ${toString i}") (builtins.genList (i: i + 1) 9))
          ++ (map (i: "$mod SHIFT, ${toString i}, movetoworkspace, ${toString i}") (builtins.genList (i: i + 1) 9));

        bindm = [
          "$mod, mouse:272, movewindow"
          "$mod, mouse:273, resizewindow"
        ];
      };
    };

    programs.waybar = {
      enable = true;
      systemd.enable = true;
      settings.mainBar = {
        layer = "top";
        position = "top";
        height = 32;
        modules-left = [ "hyprland/workspaces" ];
        modules-center = [ "clock" ];
        modules-right = [ "pulseaudio" "network" "battery" "tray" ];
        clock.format = "{:%a %b %d  %H:%M}";
      };
      style = ''
        * {
          font-family: "JetBrainsMono Nerd Font", sans-serif;
          font-size: 13px;
        }
        window#waybar {
          background-color: #1a1b26;
          color: #c0caf5;
        }
        #workspaces button.active {
          color: #7aa2f7;
        }
        #clock, #pulseaudio, #network, #battery, #tray {
          padding: 0 10px;
          color: #c0caf5;
        }
      '';
    };

    programs.hyprlock = {
      enable = true;
      settings = {
        background = [{
          path = "screenshot";
          blur_passes = 2;
          color = "rgba(26, 27, 38, 1.0)"; # Tokyo Night background
        }];
        input-field = [{
          size = "250, 60";
          outer_color = "rgb(122, 162, 247)"; # Tokyo Night blue
          inner_color = "rgb(26, 27, 38)"; # Tokyo Night background
          font_color = "rgb(192, 202, 245)"; # Tokyo Night foreground
        }];
      };
    };

    # Idle management: lock after 5 minutes, matching this repo's convention
    # on niri/hyprland (swayidle there; hypridle here since it's Omarchy's
    # native choice and pairs directly with hyprlock above).
    services.hypridle = {
      enable = true;
      settings = {
        general = {
          lock_cmd = "pidof hyprlock || hyprlock";
          before_sleep_cmd = "loginctl lock-session";
        };
        listener = [
          {
            timeout = 300;
            on-timeout = "loginctl lock-session";
          }
        ];
      };
    };

    # Walker: Omarchy's own application launcher (confirmed via /research —
    # invoked Super+Space in real Omarchy). Works standalone via its default
    # desktop-file provider; Omarchy also pairs it with a backend daemon
    # called "elephant" for richer providers, deliberately left out here to
    # keep this module in scope (theme + keybind philosophy, not a full
    # Omarchy replica).
    home.packages = with pkgs; [ walker ];
  };
}
