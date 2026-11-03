{ ... }:

{
  # Tailscale mesh VPN — the fleet's device-to-device network. It began
  # 2026-08-18 as a stopgap when Oracle Cloud disabled the WireGuard hub
  # (vpn-server, retired 2026-11-03). See project_tailscale_evaluation memory
  # for the original draft this was pulled forward from.
  #
  # Mesh-only: no exit-node/subnet-routing configured, so it connects the
  # fleet's own devices but does not mask egress IP — that is the Proton VPN
  # client's job (modules/proton-vpn.nix).
  #
  # First-time auth is manual on every host: after rebuild, run
  # `sudo tailscale up` and follow the printed login URL. Expanded from
  # gaming-only to laptop + natalie-laptop on 2026-08-18; manual per-host
  # auth was deliberately kept (not an authKeyFile via sops-nix) — still
  # just 3 ad-hoc hosts, not a scale where automated auth pays for itself.
  services.tailscale.enable = true;
}
