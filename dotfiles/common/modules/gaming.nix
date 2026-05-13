{ pkgs, ... }:

{
  # Enable hardware for controllers, etc...
  hardware.steam-hardware.enable = true;

  # Configure programs
  programs = {
    # Steam
    steam = {
      enable = true;
      remotePlay.openFirewall = false;
      dedicatedServer.openFirewall = false;
      localNetworkGameTransfers.openFirewall = false;

      # Global steam optional launch settings
      package = pkgs.steam.override {
        extraEnv = {
          ENABLE_VKBASALT = "1";
          GAMEMODERUN = "1";
          PROTON_ENABLE_NVAPI = "1";
          PROTON_ENABLE_WAYLAND = "1";
          PROTON_FSR4_UPGRADE = "1";
        };
      };
    };

    # Gamemode
    gamemode.enable = true;

    # Gamescope
    gamescope.enable = true;

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

  # Gaming packages
  environment.systemPackages = with pkgs; [
    faugus-launcher
    heroic
    # lutris
    mangohud
    mangojuice
    protontricks
    protonup-qt
    r2modman
    vkbasalt
    vulkan-tools
  ];
}
