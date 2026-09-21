{ pkgs, config, ... }:

{
  # WireGuard server (wg0) that the desktop hosts' full-tunnel clients
  # (modules/vpn.nix) connect to.
  networking = {
    firewall = {
      allowedUDPPorts = [ 51820 ];

      # Accept forwarded packets from WireGuard peers
      trustedInterfaces = [ "wg0" ];

      # Allow asymmetric routing for NAT — return traffic arrives on enp0s6,
      # not wg0, so strict reverse-path check would drop it
      checkReversePath = "loose";
    };

    wg-quick.interfaces.wg0 = {
      address = [ "10.10.0.1/24" ];
      listenPort = 51820;
      privateKeyFile = config.sops.secrets."wg-private-key".path;

      # Oracle's route cache reports MTU 9000 for the default route (its
      # internal jumbo-frame VCN fabric) even though the physical NIC and the
      # real path to external peers is 1500. Left unset, wg-quick auto-detects
      # off that inflated route MTU and picks 8920, which then needs IP
      # fragmentation to leave the 1500-byte physical link — fragmented UDP is
      # exactly what gets silently dropped by ISPs/NAT/firewalls along the way,
      # causing random stutter (worst on latency-sensitive traffic like
      # gaming) instead of a clean drop. Match the client-side clamp
      # (modules/vpn.nix) so both ends agree on a safe real-world MTU.
      mtu = 1380;

      # NAT masquerade: rewrite source IP so return traffic knows to come back
      # to the server. FORWARD accept is handled declaratively via trustedInterfaces.
      postUp = ''
        ${pkgs.iptables}/bin/iptables -t nat -A POSTROUTING -o enp0s6 -j MASQUERADE
      '';
      preDown = ''
        ${pkgs.iptables}/bin/iptables -t nat -D POSTROUTING -o enp0s6 -j MASQUERADE
      '';

      peers = [
        {
          # gaming
          publicKey = "M9KajsVX9wKLyeqz8F4kXbtelJYxYZP2b+cvkYMZ+nA=";
          allowedIPs = [ "10.10.0.2/32" ];
        }
        {
          # laptop
          publicKey = "c4H2dY7dGuvanWpmpChT4vocjDPB+pbC8KeLJ2N8m3s=";
          allowedIPs = [ "10.10.0.3/32" ];
        }
        {
          # natalie-laptop
          publicKey = "YRrCAJ44V1y9uVkt7NWk8w61TDlU4o1G0MDLH0GSpSE=";
          allowedIPs = [ "10.10.0.4/32" ];
        }
      ];
    };
  };

  # WireGuard private key, supplied by sops-nix (decrypted to /run/secrets).
  sops.secrets."wg-private-key".sopsFile = ../../secrets/hosts/vpn-server.yaml;

  # Enable IP forwarding for routing client traffic
  boot.kernel.sysctl."net.ipv4.ip_forward" = 1;
}
