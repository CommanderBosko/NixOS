{ pkgs, ... }:

{
  services.displayManager = {
    sddm = {
      enable = true;
      wayland.enable = true;
      theme = "sddm-astronaut-theme";
      autoNumlock = true;
      # sddm-astronaut ships the theme; qtmultimedia is needed for its
      # animated/video backgrounds under the Qt6/Wayland greeter.
      extraPackages = [ pkgs.kdePackages.qtmultimedia ];
    };
  };

  # Make the sddm-astronaut theme available to the greeter.
  environment.systemPackages = [ pkgs.sddm-astronaut ];

  # Enable XDG portals
  xdg.portal = {
    enable = true;
  };

  # Enable dconf for GTK settings
  programs.dconf.enable = true;
}
