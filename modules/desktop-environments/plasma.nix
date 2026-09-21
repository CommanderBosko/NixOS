{ pkgs, ... }:

{
  services = {
    # Enable Plasma 6 desktop environment
    desktopManager.plasma6.enable = true;

    # Enable x11
    xserver.enable = true;
  };

  # Everything else Plasma needs (dolphin, konsole, spectacle, discover,
  # print-manager) is already installed by services.desktopManager.plasma6.
  environment.systemPackages = [
    pkgs.kdePackages.krohnkite # Tiling window manager script
  ];
}
