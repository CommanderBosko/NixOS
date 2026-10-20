{ lib, ... }:

# Firewall for the media box.
#
# What should be reachable, and from where:
#   - SSH (22/tcp): LAN and tailnet. The router doesn't forward 22, so opening it on every
#     interface is fine.
#   - Jellyfin (8096/tcp): LAN and tailnet.
#   - Pinchflat web UI (8945/tcp): LAN only.
#   - Prometheus (9090/tcp): tailnet only. It has no authentication.
#   - WireGuard server for the travel laptop (51820): from the internet; the router forwards
#     it here.
#   - When I'm away this box sends its own traffic through a Tailscale exit node, so
#     Tailscale's client routing has to keep working.

{
  services.tailscale = {
    enable = true;
    useRoutingFeatures = "client";
  };

  networking.wireguard.interfaces.wg0 = {
    ips = [ "10.10.0.1/24" ];
    listenPort = 51820;
    privateKeyFile = "/run/secrets/wireguard/private-key";
    peers = [
      {
        # travel laptop
        publicKey = "dHJhdmVsLWxhcHRvcC1wdWJrZXktbm90LXJlYWwhISE=";
        allowedIPs = [ "10.10.0.3/32" ];
      }
    ];
  };

  services.prometheus = {
    enable = true;
    port = 9090;
  };

  networking.firewall = {
    enable = true;

    # Hardening: strict reverse-path filtering everywhere.
    checkReversePath = lib.mkForce true;

    allowedTCPPorts = [
      22 # ssh
      9090 # prometheus
      51820 # wireguard
    ];

    interfaces = {
      enp4s0.allowedTCPPorts = [
        8096 # jellyfin
        8945 # pinchflat
      ];
      tailscale0.allowedTCPPorts = [
        8096 # jellyfin
      ];
    };
  };
}
