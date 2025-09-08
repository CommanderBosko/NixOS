{ config, pkgs, ... }:

{
  # Configure networking
  networking = {
    # Set host name
    hostName = "venom";

    # Enable network manager
    networkmanager.enable = true;
  };
}
