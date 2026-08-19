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

    # Enable custom DNS servers. Points at pi-hole's stable Tailscale IP
    # (not its LAN IP) so filtered DNS keeps working off the home LAN too —
    # e.g. laptop/natalie-laptop away from home, as long as Tailscale is up.
    # Requires pi-hole's own dns.listeningMode = "ALL" (set 2026-08-18; its
    # default "LOCAL" mode silently drops queries from Tailscale's
    # point-to-point /32 addressing). 1.1.1.1 stays as a fallback if
    # Tailscale or pi-hole is unreachable.
    nameservers = [
      "100.92.242.60"
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
