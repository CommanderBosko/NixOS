{ pkgs, inputs, ... }:

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
  };

  # Host-specific packages, on top of the shared modules/desktop-apps.nix list
  environment.systemPackages = with pkgs; [
    inputs.financeguru.packages.${pkgs.stdenv.hostPlatform.system}.default
    anki
    kdePackages.okular
    qutebrowser
    rpi-imager
  ];
}
