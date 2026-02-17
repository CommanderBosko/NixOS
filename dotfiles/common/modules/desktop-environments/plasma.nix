{ config, pkgs, ... }:

{
  services = {
  	# Enable Plasma 6 desktop environment
  	desktopManager.plasma6.enable = true;

    # Enable x11
    xserver.enable = true;
  };

  # Add common Plasma utilities and applications
  environment.systemPackages = with pkgs; [
    kdePackages.discover # Software center
    kdePackages.dolphin # File manager
    kdePackages.konsole # Terminal emulator
    kdePackages.spectacle # Screenshot tool
    # Add other desired KDE applications here, using kdePackages prefix
    # For example: kdePackages.kdenlive, kdePackages.ark
  ];

  # Additional Plasma specific configurations can go here
  # For example, enabling KScreen for display management:
#   services.dbus.packages = [
#     kdePackages.kscreen
#   ];
}
