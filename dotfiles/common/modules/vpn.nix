{ pkgs, config, ... }:

{
  # WireGuard client — shared peer/server config for gaming, laptop, natalie-laptop
  # Each host that imports this must also set:
  #   networking.wg-quick.interfaces.wg0.address = [ "<host-vpn-ip>/24" ];
  # The private key is supplied by sops-nix from secrets/hosts/<host>.yaml,
  # decrypted at activation to /run/secrets/wg-private-key.
  #
  # VPN subnet: 10.10.0.0/24
  #   vpn-server:  10.10.0.1
  #   gaming:      10.10.0.2
  #   laptop:      10.10.0.3

  # The tunnel is full-tunnel but IPv4-only (no IPv6 address on wg0, and the
  # Oracle Cloud server does not route IPv6). IPv6 is disabled system-wide so
  # IPv6-only destinations fall back to IPv4 through the tunnel instead of being
  # black-holed (e.g. TMDb image fetches in Jellyfin hung the full 100s
  # HttpClient timeout). With IPv6 disabled there is no IPv6 stack to leak, so a
  # v4-only allowedIPs (0.0.0.0/0 below) still gives a full tunnel. NOTE: do NOT
  # add "::/0" to allowedIPs — wg-quick would try `ip -6 route add ::/0 dev wg0`,
  # which fails ("IPv6 is disabled on nexthop device") and tears the whole tunnel
  # down.
  networking.enableIPv6 = false;

  environment.systemPackages = [ pkgs.wireguard-tools ];

  sops.secrets."wg-private-key".sopsFile =
    ../../../secrets/hosts/${config.networking.hostName}.yaml;

  networking.wg-quick.interfaces.wg0 = {
    privateKeyFile = config.sops.secrets."wg-private-key".path;
    dns = [ "1.1.1.1" "8.8.8.8" ];

    # wg-quick defaults to MTU 1420, but the underlying path to the Oracle
    # endpoint can only carry ~1400-byte inner packets. With PMTU discovery
    # black-holed, full-size packets are silently dropped, which truncates large
    # downloads (e.g. nars from cache.nixos.org) while pings/small packets pass.
    # Clamp to 1380 to stay safely under the path MTU.
    mtu = 1380;

    peers = [
      {
        # vpn-server (Oracle Cloud ARM — 150.136.232.63)
        publicKey = "ijhN7KUmHx5TOLpKgyzJpzSvp49TkD0c2CTf32Cyu1U=";
        endpoint = "150.136.232.63:51820";

        # Full tunnel: route all IPv4 traffic through the VPN (v4-only — see note above)
        allowedIPs = [ "0.0.0.0/0" ];

        # Oracle Cloud silently drops idle UDP after ~30s; keep-alive prevents that
        persistentKeepalive = 25;
      }
    ];
  };
}
