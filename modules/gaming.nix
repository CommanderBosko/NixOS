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
        libICE
        libpulseaudio
        libSM
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
        libXinerama
        libXrandr
        libXrender
        libXt
        libXtst
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

  # Waydroid — Android in a container for mobile games. The nixpkgs module
  # also enables LXC, trusts waydroid0 in the firewall, and asserts kernel
  # binder support (built into linux-zen here). After the first rebuild run
  # `sudo waydroid init` once; on the current NVIDIA card it falls back to
  # software rendering (full GPU acceleration needs the AMD swap).
  # waydroid-nftables: linux-zen ships no legacy ip_tables module, so the
  # default package's waydroid-net.sh (legacy iptables) fails on every start.
  virtualisation.waydroid = {
    enable = true;
    package = pkgs.waydroid-nftables;
  };

  # Gaming packages
  environment.systemPackages = with pkgs; [
    faugus-launcher
    heroic
    lutris
    mangohud
    mangojuice
    protontricks
    protonup-qt
    r2modman
    vkbasalt
    vulkan-tools
  ];
}
