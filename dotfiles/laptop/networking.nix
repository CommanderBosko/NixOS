{ config, pkgs, ... }:

{
  # Configure networking
  networking = {
    # Set host name
    hostName = "venom";

    # wireless.enable = true;  # Enables wireless support via wpa_supplicant.

    # Configure network proxy if necessary
    # proxy.default = "http://user:password@proxy:port/";
    # proxy.noProxy = "127.0.0.1,localhost,internal.domain";

    # Enable network manager
    networkmanager.enable = true;

    # Openvpn setup
    # services.openvpn.servers = {
      # homeVPN = { config = '' config ./dotfiles/vpn/us11656.manassas1.nordvpn.conf ''; };
      # pVPN = { config = '' config ./dotfiles/vpn/us10399.newYork.nordvpn.conf ''; };
    # };

    # Enable the OpenSSH daemon.
    # services.openssh.enable = true;

    # Enable and open ports in the firewall
    firewall = {
      enable = true;
      # firewall.allowedTCPPorts = [ ... ];
      # firewall.allowedUDPPorts = [ ... ];
    };
  };
}
