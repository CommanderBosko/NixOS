{ config, pkgs, host, ... }:

{
  # Configure networking
  networking = {
    # Set host name
    hostName = host;

    # Enable network manager
    networkmanager.enable = true;
  };
}
