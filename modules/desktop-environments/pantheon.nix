{ ... }:

{
  # Enable X11 server (Pantheon is X11-native)
  services.xserver.enable = true;

  # Enable Pantheon desktop environment (installs its default apps, incl.
  # elementary-files and elementary-terminal, itself)
  services.desktopManager.pantheon.enable = true;
}
