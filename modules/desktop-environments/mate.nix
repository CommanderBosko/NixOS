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
    caja # File manager
    mate-panel-with-applets
    mate-terminal
    # Add other desired MATE applications here
  ];
}
