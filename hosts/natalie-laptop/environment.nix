{ pkgs, inputs, lib, ... }:

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
      };
    };

    # Enable graphical interface
    graphics.enable = true;

    # This machine's discrete GPU (PCI 10de:1c94, Pascal-era) predates the
    # GSP firmware the open kernel module requires — NVRM probe fails with
    # "not supported by open nvidia.ko" on every boot under modules/nvidia.nix's
    # default. Fall back to the proprietary closed module instead.
    nvidia.open = lib.mkForce false;
  };

  # Host-specific packages, on top of the shared modules/desktop-apps.nix list
  environment.systemPackages = with pkgs; [
    inputs.financeguru.packages.${pkgs.stdenv.hostPlatform.system}.default
    anki
    qutebrowser
    rpi-imager
    simple-scan
  ];
}
