{ ... }:

{
  # Networking shared by every desktop host (gaming, laptop, natalie-laptop).
  # Host networking.nix files keep only what is genuinely host-specific: the
  # WireGuard client address and any extra SSH AllowUsers entries.
  # networking.hostName is set from the flake attribute name (see mkSystem).

  # Configure networking
  networking = {
    # Enable networking
    networkmanager = {
      enable = true;
      dns = "none";
    };

    # Enable custom DNS servers
    nameservers = [
      "10.0.0.19"
      "1.1.1.1"
    ];

    # Enable and open ports in the firewall
    firewall = {
      enable = true;
      allowedTCPPorts = [ 22 ];
    };
  };

  services = {
    # Network clock sync
    chrony.enable = true;

    # Enable and configure openssh
    openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = false;
        PermitRootLogin = "no";
        PrintMotd = false;
        # List option — host files can append users (e.g. natty on natalie-laptop)
        AllowUsers = [ "bosko" ];
      };
    };
  };
}
