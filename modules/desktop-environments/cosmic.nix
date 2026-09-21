{ lib, ... }:

{
  services = {
    # Disable SDDM since cosmic-greeter is used
    displayManager.sddm.enable = lib.mkForce false;

    # Enable Cosmic desktop environment
    desktopManager.cosmic.enable = true;

    # Enable Cosmic Greeter (display manager)
    displayManager.cosmic-greeter.enable = true;
  };

  # Cosmic is Wayland-native, so xserver isn't enabled; XWayland is handled
  # automatically where needed.
}
