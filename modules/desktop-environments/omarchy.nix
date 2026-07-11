{ pkgs, inputs, ... }:

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
    hyprshot # Screenshot utility (region/window/output), Omarchy's actual tool
    hyprpicker # Wayland color picker
    clipse # Clipboard manager TUI
    swaybg # Solid-color background — no bundled wallpaper asset in this repo
    wl-clipboard # Wayland clipboard utilities
    wlr-randr # RandR utility for Wayland
    playerctl # MPRIS media control
    xdg-desktop-portal-hyprland
  ];

  # Home Manager: Omarchy-style shell (Waybar status bar, Hyprlock screen
  # locker, mako notifications, Walker app launcher — Omarchy's actual
  # defaults, confirmed via /research), themed through a real base16 palette
  # (nix-colors) rather than hand-copied hex codes, with a keyboard-driven
  # Hyprland config mirroring Omarchy's real keybind set (screenshots, color
  # picker, clipboard manager, Escape-key session controls).
  # Scoped to theme + keybind philosophy only — this repo's existing app
  # choices (kitty, dolphin) are kept rather than swapping in Omarchy's own
  # picks (Ghostty, Nautilus). Known gap: dolphin has no Qt/KDE theming glue
  # here (unlike niri.nix/hyprland.nix's qt6ct+kdeglobals setup, which is
  # coupled to DMS's matugen color generation and doesn't apply without DMS
  # running) — it will render in Qt's default light style. Omarchy's live
  # keybindings-cheatsheet script (bound to a key, piped through the
  # launcher's dmenu mode) is also left out — Walker's dmenu invocation
  # wasn't worth wiring up untested for a cosmetic feature.
  home-manager.users.bosko = { config, pkgs, ... }:
    let
      palette = config.colorScheme.palette;
      # Hyprland/hyprlock (hyprlang) color syntax: hex packed inside
      # rgb()/rgba(), no separators. mako and Waybar's CSS use plain
      # "#hex" instead — see their blocks below.
      rgb = hex: "rgb(${hex})";
      rgba = hex: alpha: "rgba(${hex}${alpha})";
    in
    {
      imports = [ inputs.nix-colors.homeManagerModules.default ];

      # Single source of truth for every color below. Swap this one line to
      # retheme the whole DE (Hyprland borders, Waybar, Hyprlock, mako) —
      # matches Omarchy's actual signature feature (instant, unified
      # theme-switching) instead of the hardcoded-hex approach this module
      # used before. Picking a different nix-colors scheme name is enough;
      # no other file needs to change.
      colorScheme = inputs.nix-colors.colorSchemes."tokyo-night-dark";

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

          exec-once = [
            "waybar"
            "hypridle"
            "mako"
            "swaybg -c '#${palette.base00}'"
          ];

          # Wayland/Qt/GTK env glue Omarchy sets so Electron/Qt/SDL/Firefox
          # apps actually run native-Wayland instead of falling back to
          # XWayland, plus a consistent cursor theme. NVIDIA-specific vars
          # (GBM_BACKEND, __GLX_VENDOR_LIBRARY_NAME, LIBVA_DRIVER_NAME) are
          # deliberately NOT duplicated here — modules/nvidia.nix already
          # sets those at environment.sessionVariables for every host that
          # imports it, regardless of DE.
          env = [
            "GDK_BACKEND,wayland"
            "QT_QPA_PLATFORM,wayland"
            "SDL_VIDEODRIVER,wayland"
            "MOZ_ENABLE_WAYLAND,1"
            "OZONE_PLATFORM,wayland"
            "ELECTRON_OZONE_PLATFORM_HINT,wayland"
            "XCURSOR_THEME,Adwaita"
            "XCURSOR_SIZE,24"
            "HYPRCURSOR_THEME,Adwaita"
            "HYPRCURSOR_SIZE,24"
          ];

          general = {
            gaps_in = 4;
            gaps_out = 8;
            border_size = 2;
            "col.active_border" = rgba palette.base0D "ff"; # accent (blue)
            "col.inactive_border" = rgba palette.base09 "aa"; # muted accent
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

          windowrule = [
            "suppressevent maximize, class:.*"
            "opacity 0.97 0.9, class:.*"
            # Float + size clipse's clipboard-history popup instead of tiling it
            "float, class:(clipse)"
            "size 622 652, class:(clipse)"
            "stayfocused, class:(clipse)"
          ];

          layerrule = [
            "blur, waybar"
            # Walker draws its own blur via ext-background-effect-v1, not a
            # compositor layerrule, so no entry for it here.
          ];

          bind =
            [
              "$mod, Return, exec, $terminal"
              "$mod, Space, exec, $menu"
              "$mod, E, exec, $fileManager"
              "$mod, Q, killactive"
              "$mod, V, togglefloating"
              "$mod, F, fullscreen"

              "$mod, left, movefocus, l"
              "$mod, right, movefocus, r"
              "$mod, up, movefocus, u"
              "$mod, down, movefocus, d"

              # Session controls (Omarchy's Escape-key convention)
              "$mod, ESCAPE, exec, hyprlock"
              "$mod SHIFT, ESCAPE, exit"
              "$mod CTRL, ESCAPE, exec, reboot"
              "$mod SHIFT CTRL, ESCAPE, exec, systemctl poweroff"

              # Screenshots + color picker
              ", PRINT, exec, hyprshot -m region"
              "SHIFT, PRINT, exec, hyprshot -m window"
              "CTRL, PRINT, exec, hyprshot -m output"
              "$mod, PRINT, exec, hyprpicker -a"

              # Clipboard manager
              "$mod CTRL, V, exec, kitty --class clipse -e clipse"
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
            background-color: #${palette.base00};
            color: #${palette.base05};
          }
          #workspaces button.active {
            color: #${palette.base0D};
          }
          #clock, #pulseaudio, #network, #battery, #tray {
            padding: 0 10px;
            color: #${palette.base05};
          }
        '';
      };

      programs.hyprlock = {
        enable = true;
        settings = {
          background = [{
            path = "screenshot";
            blur_passes = 2;
            color = rgba palette.base00 "ff";
          }];
          input-field = [{
            size = "250, 60";
            outer_color = rgb palette.base0D;
            inner_color = rgb palette.base00;
            font_color = rgb palette.base05;
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

      # mako: Omarchy's actual notification daemon. Colors are plain "#hex"
      # here (mako's own config syntax), not the rgb()/rgba() hyprlang form
      # used above for Hyprland/hyprlock.
      services.mako = {
        enable = true;
        settings = {
          background-color = "#${palette.base00}";
          text-color = "#${palette.base05}";
          border-color = "#${palette.base0D}";
          border-size = 2;
          border-radius = 8;
          width = 380;
          height = 100;
          padding = "10";
          margin = "10";
          anchor = "top-right";
          default-timeout = 5000;
          max-visible = 5;
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
