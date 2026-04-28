{ pkgs, ... }:

{
  # Bootloader for Oracle Cloud ARM (aarch64 EFI, systemd-boot)
  boot = {
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
  };

  networking = {
    hostName = "vpn-server";

    firewall = {
      enable = true;
      allowedUDPPorts = [ 51820 ];
      allowedTCPPorts = [ 22 ];
    };

    wg-quick.interfaces.wg0 = {
      address = [ "10.0.0.1/24" ];
      listenPort = 51820;
      privateKeyFile = "/etc/wireguard/private.key";

      # Route all client traffic through the server
      postUp = ''
        ${pkgs.iptables}/bin/iptables -A FORWARD -i wg0 -j ACCEPT
        ${pkgs.iptables}/bin/iptables -t nat -A POSTROUTING -o enp0s3 -j MASQUERADE
      '';
      preDown = ''
        ${pkgs.iptables}/bin/iptables -D FORWARD -i wg0 -j ACCEPT
        ${pkgs.iptables}/bin/iptables -t nat -D POSTROUTING -o enp0s3 -j MASQUERADE
      '';

      peers = [
        {
          # gaming — fill in after generating keys on gaming
          publicKey = "GAMING_PUBLIC_KEY";
          allowedIPs = [ "10.0.0.2/32" ];
        }
        {
          # laptop — fill in after generating keys on laptop
          publicKey = "LAPTOP_PUBLIC_KEY";
          allowedIPs = [ "10.0.0.3/32" ];
        }
      ];
    };
  };

  # Enable IP forwarding for routing client traffic
  boot.kernel.sysctl."net.ipv4.ip_forward" = 1;

  services = {
    openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = false;
        PermitRootLogin = "no";
      };
    };

    # Automatic cleanup
    journald.extraConfig = "SystemMaxUse=200M";
  };

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 7d";
    persistent = true;
  };

  environment.systemPackages = with pkgs; [
    wireguard-tools
  ];
}
