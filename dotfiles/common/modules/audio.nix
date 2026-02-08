{ config, pkgs, ... }:

{
  # Enable and configure pipewire
  services = {
    pipewire = {
      enable = true;
      alsa = {
        enable = true;
        support32Bit = true;
      };

      pulse.enable = true;
    };

    # Pulseaudio is pretty outdated at this point
    pulseaudio.enable = false;
  };

  security.rtkit.enable = true;
}
