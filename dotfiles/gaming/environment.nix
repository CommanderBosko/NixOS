{ pkgs, ... }:

{
  # Services
  services = {
    # Display manager settings
    displayManager = {
      autoLogin = {
        enable = true;
        user = "bosko";
      };
    };

    # Enable printing
    printing.enable = true;
  };

  # Hardware
  hardware = {
    # Bluetooth settings
    bluetooth = {
      enable = false;
      powerOnBoot = false;
      settings.General = {
        Enable = "Source,Sink,Media,Socket";
        Experimental = true;
      };
    };

    # Enable graphical interface
    graphics.enable = true;
  };

  # Programs
  programs = {
    # Shell aliases
    zsh.shellAliases = {
      rift = "~/Rift/bin/rift";
    };

    # Dynamic library loader (nix-ld)
    nix-ld = {
      enable = true;
      libraries = with pkgs; [
        alsa-lib
        atk
        cairo
        dbus
        expat
        fontconfig
        freetype
        gdk-pixbuf
        glib
        gtk2
        gtk3
        krb5
        libdrm
        libGL
        libpulseaudio
        libusb1
        libva
        libvdpau
        libX11
        libXau
        libXcomposite
        libXcursor
        libXdamage
        libXdmcp
        libXext
        libXfixes
        libXi
        libICE
        libXinerama
        libXrandr
        libXrender
        libSM
        libXtst
        libXt
        mesa
        nspr
        nss
        pango
        pipewire
        SDL2
        SDL2_mixer
        udev
        vulkan-loader
        wayland
        xwayland
        zlib
        zulu
      ];
    };
  };

  # System packages
  environment.systemPackages = with pkgs; [
    brave
    chromium
    deezer-enhanced
    discord
    firefox
    freetube
    gemini-cli
    gparted
    kdePackages.kate
    kitty
    megasync
    nix-ld
    obs-studio
    onlyoffice-desktopeditors
    p7zip
    qalculate-qt
    tor-browser
    vesktop
    vivaldi
    vlc
  ];

  # Flatpaks
  services.flatpak.packages = [
    "com.albiononline.AlbionOnline" # Albion Online
    "org.kde.digikam" # Digikam
    "app.zen_browser.zen" # Zen Browser
  ];
}
