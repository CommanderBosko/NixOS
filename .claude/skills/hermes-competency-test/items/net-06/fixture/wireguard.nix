{ config, ... }:

{
  # Client side of the WireGuard tunnel from the laptop to the hub.
  networking.wireguard.interfaces.wg0 = {
    ips = [ "10.10.0.3/24" ];
    listenPort = 51820;
    privateKeyFile = config.sops.secrets."wireguard/laptop-private".path;

    peers = [
      {
        # hub
        publicKey = "aHViLXB1YmxpYy1rZXktZXhhbXBsZS1ub3QtcmVhbCE=";
        endpoint = "203.0.113.10:51820";
        allowedIPs = [ "10.10.0.0/24" ];
        persistentKeepalive = 25;
      }
    ];
  };

  sops.secrets."wireguard/laptop-private" = { };
}
