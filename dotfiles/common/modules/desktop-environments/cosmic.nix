{ config, pkgs, ... }:

{
  # Enable Cosmic desktop environment
  services.desktopManager.cosmic.enable = true;

  # Enable Cosmic Greeter (display manager)
  services.displayManager.cosmic-greeter = {
    enable = true;
    # Optional: Enable autologin for a specific user
    # autologin.enable = true;
    # autologin.user = "your-username";
  };

  # Cosmic DE is Wayland-native, no need to enable xserver generally.
  # If XWayland is needed for specific applications, it's usually handled automatically or via other modules.

  # Add common Cosmic DE related packages (example, adjust as needed)
  environment.systemPackages = with pkgs; [
    cosmic-epoch # The main cosmic package
    # Add other desired Cosmic-related applications or utilities here
    # For example: cosmic-files, cosmic-text-editor
  ];

  # Optional: Enable System76 scheduler for performance (especially on System76 hardware)
  # services.system76-scheduler.enable = true;
}
