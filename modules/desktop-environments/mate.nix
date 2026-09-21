{ ... }:

{
  # The MATE module installs the desktop and its default apps itself (caja,
  # mate-panel with applets, mate-terminal, ...).
  services.xserver = {
    # Enable X11 server (MATE is X11-native)
    enable = true;

    # Enable MATE desktop environment
    desktopManager.mate.enable = true;
  };
}
