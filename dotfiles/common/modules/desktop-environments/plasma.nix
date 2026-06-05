{ pkgs, ... }:

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
    kdePackages.krohnkite # Tiling window manager script
    kdePackages.print-manager # Print job manager
    kdePackages.spectacle # Screenshot tool
  ];

  # Additional Plasma specific configurations can go here
  # For example, enabling KScreen for display management:
  #   services.dbus.packages = [
  #     kdePackages.kscreen
  #   ];
}
