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
  # Oracle Cloud server does not route IPv6). With IPv6 enabled, the "::/0"
  # allowedIPs below pulls all IPv6 traffic into a tunnel that can't carry it,
  # black-holing any IPv6-only destination (e.g. TMDb image fetches in Jellyfin
  # hung the full 100s HttpClient timeout). Disabling IPv6 forces DNS/connections
  # to fall back to IPv4 through the tunnel — fixes the black-hole AND keeps the
  # full-tunnel guarantee intact (no IPv6 leak around the VPN).
  networking.enableIPv6 = false;

  environment.systemPackages = [ pkgs.wireguard-tools ];

  sops.secrets."wg-private-key".sopsFile =
    ../../../secrets/hosts/${config.networking.hostName}.yaml;

  networking.wg-quick.interfaces.wg0 = {
    privateKeyFile = config.sops.secrets."wg-private-key".path;
    dns = [ "1.1.1.1" "8.8.8.8" ];

    peers = [
      {
        # vpn-server (Oracle Cloud ARM — 150.136.232.63)
        publicKey = "ijhN7KUmHx5TOLpKgyzJpzSvp49TkD0c2CTf32Cyu1U=";
        endpoint = "150.136.232.63:51820";

        # Full tunnel: route all traffic through the VPN
        allowedIPs = [ "0.0.0.0/0" "::/0" ];

        # Oracle Cloud silently drops idle UDP after ~30s; keep-alive prevents that
        persistentKeepalive = 25;
      }
    ];
  };
}
