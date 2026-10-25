{ ... }:

{
  # Host metrics for gaming's Prometheus (hosts/gaming/monitoring.nix). Shared
  # by every desktop so the laptops get scraped too.
  services.prometheus.exporters.node = {
    enable = true;
    # `systemd` feeds the SystemdUnitFailed alert. Limited to .service units to
    # keep the series count down (every unit x 5 states otherwise).
    enabledCollectors = [ "systemd" ];
    extraFlags = [ "--collector.systemd.unit-include=.+[.]service" ];
  };

  # Reachable over Tailscale only, never the LAN or the internet. The exporter
  # itself listens on all interfaces; the per-interface firewall rule is the gate.
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 9100 ];
}
