{ pkgs, ... }:

{
  networking.wg-quick.interfaces.wg0 = {
    address = [ "10.0.0.2/24" ];
    privateKeyFile = "/etc/wireguard/private.key";
    autostart = false;

    peers = [
      {
        # vpn-server public key — fill in after server is deployed
        publicKey = "SERVER_PUBLIC_KEY";
        # Oracle VM public IP — fill in after server is deployed
        endpoint = "SERVER_PUBLIC_IP:51820";
        allowedIPs = [
          "0.0.0.0/0"
          "::/0"
        ];
        persistentKeepalive = 25;
      }
    ];
  };

  programs.zsh.shellAliases = {
    vpn-up = "sudo systemctl start wg-quick-wg0";
    vpn-down = "sudo systemctl stop wg-quick-wg0";
    vpn-status = "sudo wg show";
  };

  environment.systemPackages = with pkgs; [
    oci-cli
  ];
}
