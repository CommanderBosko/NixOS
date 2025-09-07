{ config, pkgs, host, ... }:

{
  networking = {
    # Set host name
    hostName = host;

    # Enable network manager
    networkmanager.enable = true;
  };
}
