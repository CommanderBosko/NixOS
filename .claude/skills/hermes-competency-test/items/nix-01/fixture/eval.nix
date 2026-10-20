# Prints the merged metrics-agent unit settings. From the repo root:
#   nix-instantiate --eval --strict task/eval.nix
let
  nixpkgs = builtins.getFlake "nixpkgs";
  system = import "${nixpkgs}/nixos/lib/eval-config.nix" {
    system = "x86_64-linux";
    modules = [
      ./upstream/metrics-agent.nix
      ./override.nix
    ];
  };
  svc = system.config.systemd.services.metrics-agent;
in
{
  inherit (svc) wantedBy after;
  inherit (svc.serviceConfig) ExecStart Restart MemoryMax;
  logLevel = svc.environment.METRICS_LOG_LEVEL;
}
