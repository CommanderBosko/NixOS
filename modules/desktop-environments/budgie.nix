{ ... }:

{
  # The Budgie module installs the desktop itself (budgie-desktop with plugins,
  # its control center, ...) — adding the plain packages here would only
  # duplicate its overridden variants.
  services = {
    # Enable X11 server (Budgie is X11-native)
    xserver.enable = true;

    # Enable Budgie desktop environment
    desktopManager.budgie.enable = true;
  };
}
