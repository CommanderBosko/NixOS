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

    # Ename custom DNS servers
    nameservers = [ "10.0.0.20" "1.1.1.1" ];

    # Enable and open ports in the firewall
    firewall = {
      enable = true;
      # firewall.allowedTCPPorts = [ ... ];
      # firewall.allowedUDPPorts = [ ... ];
    };
  };

  # Openvpn setup
  # services.openvpn.servers = {
    # homeVPN = { config = '' config ./dotfiles/vpn/us11656.manassas1.nordvpn.conf ''; };
    # pVPN = { config = '' config ./dotfiles/vpn/us10399.newYork.nordvpn.conf ''; };
  # };
}
