{ pkgs, ... }:

{
  services = {
    # Enable X11 server
    xserver.enable = true;

    # Enable GNOME desktop environment
    desktopManager.gnome.enable = true;
  };

  # GNOME's core apps (nautilus, system monitor, console) are installed by
  # default; gnome-terminal isn't, so add it.
  environment.systemPackages = with pkgs; [
    gnome-terminal
  ];
}
