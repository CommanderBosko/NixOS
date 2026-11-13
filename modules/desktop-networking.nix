{ hostsData, ... }:

{
  # Networking shared by every desktop host (gaming, laptop, natalie-laptop).
  # Host networking.nix files keep only what is genuinely host-specific
  # (gaming's static LAN profile, extra SSH AllowUsers entries).
  # networking.hostName is set from the flake attribute name (see mkSystem);
  # the SSH server itself is configured in ssh.nix.

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
    # Tailscale or pi-hole is unreachable. The IP comes from .claude/hosts.json.
    nameservers = [
      hostsData.hosts.pi-hole.tailscaleIp
      "1.1.1.1"
    ];

    firewall.enable = true;
  };

  services = {
    # Network clock sync
    chrony.enable = true;
    # Hostname-free NTP sources (Cloudflare's anycast IPs). The default
    # nixos.pool.ntp.org entries need working DNS, but a laptop with a dead RTC
    # boots in the past, and then Tailscale can't validate TLS (so it stays
    # offline) and its MagicDNS resolver can't reach pi-hole — leaving DNS dead
    # and the pool unresolvable. A literal IP breaks that loop (hit on
    # natalie-laptop 2026-11-12: clock stuck at 2021-12-31 after a reboot).
    # IPv4 only — the VPN setup disables IPv6. makestep (default 0.1 3) lets
    # the first sync step a years-wrong clock.
    chrony.extraConfig = ''
      server 162.159.200.1 iburst
      server 162.159.200.123 iburst
    '';

    # List option — host files can append users (e.g. natty on natalie-laptop)
    openssh.settings.AllowUsers = [ "bosko" ];
  };
}
