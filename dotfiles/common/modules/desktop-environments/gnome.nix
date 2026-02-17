{ config, pkgs, ... }:

{
  services = {
    # Enable X11 server
    xserver.enable = true;

    # Enable GNOME desktop environment
    desktopManager.gnome.enable = true;
  };

  # Add common GNOME applications and utilities
  environment.systemPackages = with pkgs; [
    gnome-terminal
    nautilus
    gnome-system-monitor
    # Add other desired GNOME applications here
    # For example: gnome-calculator, gnome-text-editor
  ];

  # Optional: Exclude unwanted GNOME packages to minimize footprint
  # environment.gnome.excludePackages = with pkgs; [
  #   gnome-photos
  #   gnome-tour
  #   cheese
  #   epiphany
  #   geary
  # ];
}
