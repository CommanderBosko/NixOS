{ pkgs, ... }:

{
  # Frozen at this machine's install-time NixOS release — never bump on upgrades
  system.stateVersion = "25.11";

  # Services
  services = {
    # Enable touchpad
    libinput.enable = true;
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
  };

  # Cap charging at 80% to slow battery wear. asus_wmi exposes the firmware
  # limit as BAT0/charge_control_end_threshold; re-applied after suspend and
  # hibernate in case the firmware resets it on resume. To top up for a trip,
  # run `echo 100 | sudo tee /sys/class/power_supply/BAT0/charge_control_end_threshold`
  # (lasts until the next boot/resume).
  systemd.services.battery-charge-limit = {
    description = "Limit battery charge to 80%";
    wantedBy = [ "multi-user.target" "suspend.target" "hibernate.target" "hybrid-sleep.target" ];
    after = [ "multi-user.target" "suspend.target" "hibernate.target" "hybrid-sleep.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.runtimeShell} -c 'echo 80 > /sys/class/power_supply/BAT0/charge_control_end_threshold'";
    };
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
