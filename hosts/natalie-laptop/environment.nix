{ pkgs, ... }:

{
  # Services
  services = {
    # Enable touchpad
    libinput.enable = true;

    # Enable Qbittorrent (Web UI bound to localhost only — H-6)
    qbittorrent = {
      enable = true;
      serverConfig = {
        Preferences = {
          WebUI = {
            Address = "127.0.0.1";
          };
        };
      };
    };
  };

  # Hardware
  hardware = {
    # Bluetooth settings
    bluetooth = {
      enable = true;
      powerOnBoot = false;
      settings.General = {
        Enable = "Source,Sink,Media,Socket";
        Experimental = true;
      };
    };

    # Enable graphical interface
    graphics.enable = true;
  };

  # Qt apps default to Wayland on Cosmic (no X server running)
  environment.sessionVariables.QT_QPA_PLATFORM = "wayland;xcb";

  # System packages
  environment.systemPackages = with pkgs; [
    brave
    chromium
    firefox
    freetube
    github-desktop
    gparted
    kdePackages.kate
    kdePackages.okular
    kitty
    megasync
    onlyoffice-desktopeditors
    p7zip
    qalculate-qt
    qutebrowser
    # Wrap rpi-imager to pull WAYLAND_DISPLAY/DISPLAY from the systemd user
    # environment when they aren't inherited by the terminal — a Cosmic
    # session quirk where cosmic-comp exports these to the systemd user
    # manager but not always to login-shell descendants.
    (symlinkJoin {
      name = "rpi-imager";
      paths = [ rpi-imager ];
      nativeBuildInputs = [ makeWrapper ];
      postBuild = ''
        wrapProgram "$out/bin/rpi-imager" \
          --set QT_QPA_PLATFORM 'wayland;xcb' \
          --run '
            if [ -z "$WAYLAND_DISPLAY" ]; then
              _wl=$(systemctl --user show-environment 2>/dev/null | grep "^WAYLAND_DISPLAY=" | cut -d= -f2-)
              [ -n "$_wl" ] && export WAYLAND_DISPLAY="$_wl"
            fi
            if [ -z "$DISPLAY" ]; then
              _d=$(systemctl --user show-environment 2>/dev/null | grep "^DISPLAY=" | cut -d= -f2-)
              [ -n "$_d" ] && export DISPLAY="$_d"
            fi
          '
      '';
    })
    vesktop
    vlc
  ];

  # Flatpaks
  services.flatpak.packages = [
    "org.kde.digikam" # Digikam
    "app.zen_browser.zen" # Zen Browser
    "dev.aunetx.deezer" # Deezer
  ];
}
