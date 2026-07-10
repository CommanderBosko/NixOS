{ pkgs, ... }:

{
  # Frozen at this machine's install-time NixOS release — never bump on upgrades
  system.stateVersion = "<current-nixos-release>";

  # Services
  services = {
    # Display manager settings
    displayManager = {
      autoLogin = {
        enable = true;
        user = "bosko";
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
  ];

  # Host-specific flatpaks, on top of the shared modules/desktop-apps.nix list
  services.flatpak.packages = [
  ];
}
