{ pkgs, ... }:

{
  # Enable X11 server (Pantheon is X11-native)
  services.xserver.enable = true;

  # Enable Pantheon desktop environment
  services.desktopManager.pantheon.enable = true;

  # Pantheon installs default applications. If specific ones are needed, they can be added.
  environment.systemPackages = with pkgs; [
    pantheon.elementary-files # Pantheon's file manager
    pantheon.elementary-terminal # Pantheon's terminal (renamed upstream from pantheon-terminal)
  ];
}
