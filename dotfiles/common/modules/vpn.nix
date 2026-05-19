{ pkgs, ... }:

{
  # WireGuard client — shared peer/server config for gaming and laptop
  # Each host that imports this must also set:
  #   networking.wg-quick.interfaces.wg0.address = [ "<host-vpn-ip>/24" ];
  # and provide its private key at /etc/wireguard/private.key
  #
  # VPN subnet: 10.10.0.0/24
  #   vpn-server:  10.10.0.1
  #   gaming:      10.10.0.2
  #   laptop:      10.10.0.3

  environment.systemPackages = [ pkgs.wireguard-tools ];

  networking.wg-quick.interfaces.wg0 = {
    privateKeyFile = "/etc/wireguard/private.key";

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
