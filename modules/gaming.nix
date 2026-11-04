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
  # binder support (built into linux-zen here). On the current NVIDIA card it
  # falls back to software rendering (full GPU acceleration needs the AMD swap).
  #
  # One-time imperative setup (images are downloaded at runtime, not by Nix):
  #   sudo waydroid init -s GAPPS -f     # GAPPS image = Google Play Store
  #   # Play needs the device registered: in `sudo waydroid shell`, read the
  #   # android_id from gservices.db, register it at
  #   # https://www.google.com/android/uncertified, wait 10-20 min, restart
  #   # the session. To re-init: waydroid session stop; sudo systemctl stop
  #   # waydroid-container; init; start waydroid-container.
  #
  # ARM translation (the image is x86_64; ARM-only apps such as Wild Rift show
  # "This app won't work for your device" in Play without it). libndk suits
  # AMD CPUs, libhoudini Intel. waydroid_script isn't in nixpkgs, so run it
  # from a clone with its Python deps from nix-shell (needs root to patch the
  # system image; keep e2fsprogs/util-linux on root's PATH):
  #   git clone https://github.com/casualsnek/waydroid_script ~/waydroid_script
  #   cd ~/waydroid_script && nix-shell -p '(python3.withPackages (ps: [
  #     ps.tqdm ps.requests ps.inquirerpy ]))' e2fsprogs util-linux \
  #     --run 'sudo env PATH=$PATH python3 main.py install libndk'
  #   # (withPackages, not python3Packages.*: sudo strips PYTHONPATH)
  #   # then: waydroid session stop; sudo systemctl restart waydroid-container;
  #   # clear Play Store storage and restart the session. Re-run after any
  #   # `waydroid init -f` (it overwrites the patched image).
  #
  # waydroid-nftables: linux-zen ships no legacy ip_tables module, so the
  # default package's waydroid-net.sh (legacy iptables) fails on every start.
  virtualisation.waydroid = {
    enable = true;
    package = pkgs.waydroid-nftables;
  };

  # waydroid-container ships with no ExecStop, so on shutdown systemd SIGTERMs
  # the whole unit cgroup at once, racing waydroid's own stop handler. On
  # 2026-11-04 the handler's `lxc-info` lost that race ("Couldn't get LXC
  # status. Assuming STOPPED"), so it skipped `lxc-stop -k` and unmounted the
  # images under a still-FROZEN container; the final unmount stage then hung
  # and the next boot had to recover root's journal. Stopping the container
  # first, in ExecStop, makes that deterministic. The leading "-" ignores a
  # non-zero exit when the container isn't running.
  systemd.services.waydroid-container.serviceConfig.ExecStop = "-${pkgs.lxc}/bin/lxc-stop -P /var/lib/waydroid/lxc -n waydroid -k";

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
    wowup-cf # WoW addon manager for WoW Forever (Lutris prefix); unfree AppImage, covered by allowUnfree in nix.nix
  ];
}
