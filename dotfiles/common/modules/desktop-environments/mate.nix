{ pkgs, ... }:

{
  services.xserver = {
    # Enable X11 server (MATE is X11-native)
    enable = true;

    # Enable MATE desktop environment
    desktopManager.mate.enable = true;
  };

  # Add common MATE applications and utilities
  environment.systemPackages = with pkgs; [
    mate.mate-panel-with-applets
    mate.mate-terminal
    mate.caja # File manager
    # Add other desired MATE applications here
  ];
}
