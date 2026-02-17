{ config, pkgs, ... }:

{
  # Enable X11 server (Pantheon is X11-native)
  services.xserver.enable = true;

  # Enable Pantheon desktop environment
  services.desktopManager.pantheon.enable = true;

  # Enable SDDM display manager
  services.displayManager.sddm.enable = true;
  services.displayManager.sddm.theme = "breeze";

  # Set Pantheon as the default session for the display manager
  services.displayManager.defaultSession = "pantheon-wayland";

  # Pantheon installs default applications. If specific ones are needed, they can be added.
  environment.systemPackages = with pkgs; [
    sddm # The SDDM display manager
  #   pantheon.elementary-files # Pantheon's file manager
  #   pantheon.pantheon-terminal # Pantheon's terminal
  ];
}
