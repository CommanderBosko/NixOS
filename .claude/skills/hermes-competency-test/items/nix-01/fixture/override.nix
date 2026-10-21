# Local overrides for the vendored metrics-agent module (upstream/metrics-agent.nix).
{ lib, ... }:
{
  systemd.services.metrics-agent = {
    # I start it by hand when I need it.
    wantedBy = [ ];

    environment.METRICS_LOG_LEVEL = "debug";

    serviceConfig = {
      Restart = "always";
      MemoryMax = "256M";
    };
  };
}
