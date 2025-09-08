{ config, pkgs, ... }:

{
  # Configure networking
  networking = {
    # Set host name
    hostName = "venom";

    # Configure network proxy
    # proxy.default = "http://user:password@proxy:port/";
    # proxy.noProxy = "127.0.0.1,localhost,internal.domain";

    # Enable networking
    networkmanager = {
      enable = true;
      dns = "none";
    };

    # Enable custom DNS servers
    nameservers = [ "10.0.0.20" "1.1.1.1" ];

    # Enable and open ports in the firewall
    firewall = {
      enable = true;
#       allowedTCPPorts = [ 22 ];
#       allowedUDPPorts = [ ... ];
    };
  };

  # SSH settings
  services = {
    # Network clock sync
    ntp.enable = true;

    # Enable and configure openssh
    openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = false; # disable if using SSH keys
        PermitRootLogin = "no";
      };
    };
  };
}
