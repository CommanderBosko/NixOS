{ ... }:

{
  # The Cinnamon module installs the desktop and its default apps itself
  # (nemo, cinnamon-control-center, gnome-terminal, ...).
  services = {
    xserver = {
      # Enable X11 server (Cinnamon is X11-native)
      enable = true;

      # Enable Cinnamon desktop environment
      desktopManager.cinnamon.enable = true;
    };
  };
}
