{ pkgs, lib, ... }:

{
  # Bootloader for Oracle Cloud ARM (aarch64 EFI, systemd-boot)
  # Override commonModules/bootloader.nix which sets up GRUB + zen kernel
  # (GRUB is x86-only; zen kernel packages may not be available for aarch64)
  boot = {
    # Use the default kernel for aarch64 — zen is not reliably available on ARM
    kernelPackages = lib.mkForce pkgs.linuxPackages;

    loader = {
      grub.enable = lib.mkForce false;
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

      # Accept forwarded packets from WireGuard peers
      trustedInterfaces = [ "wg0" ];

      # Allow asymmetric routing for NAT — return traffic arrives on enp0s6,
      # not wg0, so strict reverse-path check would drop it
      checkReversePath = "loose";
    };

    wg-quick.interfaces.wg0 = {
      address = [ "10.10.0.1/24" ];
      listenPort = 51820;
      privateKeyFile = "/etc/wireguard/private.key";

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

  # Enable IP forwarding for routing client traffic
  boot.kernel.sysctl."net.ipv4.ip_forward" = 1;

  # Root SSH access — needed to connect after nixos-anywhere installs NixOS.
  # Key-only login; password auth remains off.
  users.users.root.openssh.authorizedKeys.keys = [
    # gaming
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAhUXwMqe6Eu4PRrV6BcdYYk7yRYI3x0gq+liliNhOsy kurthoernig@gmail.com"
    # laptop
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIB/EGGwStXtv/iorgMcglJYQyGLxX/bB+2quIO36c7zm kurthoernig@gmail.com"
    # natalie-laptop
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHnENcEPt+wOxR2EAu3BAcCXwErGJ4KfiANdPZH3oZfc kurthoernig@gmail.com"
  ];

  services = {
    openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = false;
        # prohibit-password: root login only via SSH key, not password.
        # Required to SSH in as root after nixos-anywhere install.
        PermitRootLogin = "prohibit-password";
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
