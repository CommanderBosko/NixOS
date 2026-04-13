{ ... }:

{
  services.displayManager = {
    sddm = {
      enable = true;
      wayland.enable = true;
      theme = "breeze";
      autoNumlock = true;
    };
  };

  # Enable XDG portals
  xdg.portal = {
    enable = true;
  };

  # Enable dconf for GTK settings
  programs.dconf.enable = true;
}
