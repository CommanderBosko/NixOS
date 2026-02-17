{ config, pkgs, ... }:

{
  # Enable X11 server
  services.xserver.enable = true;

  # Enable GDM (GNOME Display Manager)
  services.displayManager.gdm.enable = true;

  # Enable GNOME desktop environment
  services.desktopManager.gnome.enable = true;

  # Add common GNOME applications and utilities
  environment.systemPackages = with pkgs; [
    gnome.gnome-terminal
    gnome.nautilus
    gnome.gnome-system-monitor
    # Add other desired GNOME applications here
    # For example: gnome.gnome-calculator, gnome.gnome-text-editor
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
