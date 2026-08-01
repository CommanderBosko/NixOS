{ pkgs, lib, config, ... }:

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

  # Frozen at this machine's install-time NixOS release — never bump on upgrades
  system.stateVersion = "25.11";

  # hostName is set from the flake attribute name (see mkSystem)
  networking = {
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
      privateKeyFile = config.sops.secrets."wg-private-key".path;

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

  # Oracle Cloud ARM kernel doesn't support the audit subsystem; disable the
  # auditd service to prevent it from failing on every boot.
  # security.nix sets auditd.enable = true via mkDefault; mkForce overrides here.
  security.auditd.enable = lib.mkForce false;

  # nixos-rebuild --use-remote-sudo SSHes as bosko and runs sudo non-interactively;
  # a password prompt would stall the deploy over a batch SSH session.
  security.sudo.wheelNeedsPassword = false;

  # security.nix (commonModules) appends audit=1 to kernelParams.  The Oracle
  # Cloud ARM kernel's broken audit subsystem floods kauditd on boot, causing
  # PAM D-Bus timeouts that drop the nixos-rebuild SSH session mid-deploy.
  # Appending audit=0 after audit=1 wins at boot (last value takes precedence)
  # without clobbering any other kernel params.
  boot.kernelParams = lib.mkAfter [ "audit=0" ];

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

  # Oracle reclaims Always Free compute instances that stay idle over a rolling
  # 7-day window — but only when the 95th-percentile CPU, network, AND memory
  # utilisation are ALL under 20% (memory applies to A1 ARM shapes). WireGuard
  # traffic is far too light to clear any of those bars on its own. Breaking the
  # AND on a single metric is enough, so this timer burns a capped CPU load for
  # 90 min/day: that keeps >5% of the week above 20% CPU, which pins the
  # 95th-percentile figure over the threshold. Nice 19 + idle scheduling means
  # it instantly yields to real VPN traffic and never affects latency.
  #
  # The definitive fix is upgrading the account to Pay As You Go, which exempts
  # it from idle reclamation entirely while staying within the free limits — but
  # this keep-alive covers the strictly-Always-Free case with no card on file.
  systemd.services.oracle-keepalive = {
    description = "Anti-idle CPU load so Oracle doesn't reclaim the Always Free VM";
    serviceConfig = {
      Type = "oneshot";
      Nice = 19;
      CPUSchedulingPolicy = "idle";
      IOSchedulingClass = "idle";
      ExecStart = "${pkgs.stress-ng}/bin/stress-ng --cpu 0 --cpu-load 35 --timeout 90m";
    };
  };

  systemd.timers.oracle-keepalive = {
    description = "Daily anti-idle CPU load for Oracle Cloud reclamation avoidance";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* 03:00:00";
      RandomizedDelaySec = "1h";
      Persistent = true;
    };
  };

  # Weekly reboot, offset 30m past oracle-keepalive's 03:00 run so a reboot
  # doesn't cut its 90m anti-idle stress-ng job short mid-run.
  systemd.services.weekly-reboot = {
    description = "Weekly scheduled reboot";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.systemd}/bin/systemctl reboot";
    };
  };

  systemd.timers.weekly-reboot = {
    description = "Weekly reboot every Sunday at 3:30AM";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "Sun *-*-* 03:30:00";
      Persistent = false;
    };
  };

  environment.systemPackages = with pkgs; [
    wireguard-tools
  ];
}
