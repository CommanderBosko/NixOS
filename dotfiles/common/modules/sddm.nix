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
  xdg.portal.enable = true;
}
