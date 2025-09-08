{ config, pkgs, ... }:

{
  # Configure networking
  networking = {
    # Set host name
    hostName = "venom";

    # Enable network manager
    networkmanager = {
      enable = true;
      dns = "none";
    };

    # Enable custom DNS servers
    nameservers = [ "10.0.0.20" "1.1.1.1" ];
  };
}
