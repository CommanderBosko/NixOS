{ config, pkgs, ... }:

{
  services = {
    # Enable Cosmic desktop environment
    desktopManager.cosmic.enable = true;

    # Enable Cosmic Greeter (display manager)
    displayManager.cosmic-greeter = {
      enable = true;
      # Optional: Enable autologin for a specific user
      # autologin.enable = true;
      # autologin.user = "your-username";
    };
  };

  # Cosmic DE is Wayland-native, no need to enable xserver generally.
  # If XWayland is needed for specific applications, it's usually handled automatically or via other modules.


  # Optional: Enable System76 scheduler for performance (especially on System76 hardware)
  # services.system76-scheduler.enable = true;
}
