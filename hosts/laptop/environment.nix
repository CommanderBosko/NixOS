{ pkgs, ... }:

{
  # Frozen at this machine's install-time NixOS release — never bump on upgrades
  system.stateVersion = "25.11";

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
        # BAP/LE Audio needs the ISO-socket kernel-experimental feature on top
        # of Experimental=true, or bluetoothd logs "BAP requires ISO Socket
        # which is not enabled" at boot and LE Audio codecs stay unavailable.
        KernelExperimental = "6fbaf188-05e0-496a-9885-d6ddfdb4e03e";
      };
    };

    # Enable graphical interface
    graphics.enable = true;
  };

  # Qt apps default to Wayland on Niri (no X server running)
  environment.sessionVariables.QT_QPA_PLATFORM = "wayland;xcb";

  # Host-specific packages, on top of the shared modules/desktop-apps.nix list
  environment.systemPackages = with pkgs; [
    element-desktop
    qutebrowser
    rpi-imager
    tor-browser
  ];
}
