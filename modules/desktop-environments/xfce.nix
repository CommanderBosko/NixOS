{ ... }:

{
  # The XFCE module installs the whole desktop itself (panel, session,
  # settings, terminal, appfinder, xfwm4, and Thunar via programs.thunar).
  services.xserver = {
    # Enable X11 server (XFCE is X11-native primarily)
    enable = true;

    # Enable XFCE desktop environment
    desktopManager.xfce.enable = true;
  };
}
