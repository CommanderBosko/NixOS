{ pkgs, ... }:

{
  services = {
    xserver = {
      # Enable X11 server (Cinnamon is X11-native)
      enable = true;

      # Enable Cinnamon desktop environment
      desktopManager.cinnamon.enable = true;
    };
  };

  # Add common Cinnamon applications and utilities
  environment.systemPackages = with pkgs; [
    cinnamon-control-center
    gnome-terminal # Often used in Cinnamon, or an alternative
    nemo # File manager
    # Add other desired Cinnamon applications here
  ];
}
