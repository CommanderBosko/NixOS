{ ... }:

{
  # Tailscale mesh VPN — stopgap while the WireGuard hub (modules/vpn.nix,
  # vpn-server) is down. Oracle Cloud administratively disabled the
  # vpn-server instance 2026-08-18 (blanket block on all instance actions,
  # concurrent Always-Free A1 quota cut from 4/24 to 2/12 — Support ticket
  # filed, no ETA). See project_tailscale_evaluation memory for the original
  # draft this was pulled forward from.
  #
  # Mesh-only: no exit-node/subnet-routing configured, so this does NOT
  # reproduce wg0's full-tunnel egress-IP-masking behavior — it only
  # restores device-to-device connectivity. wg0 (modules/vpn.nix) is left
  # entirely untouched; the two overlay networks coexist independently.
  #
  # First-time auth is manual on every host: after rebuild, run
  # `sudo tailscale up` and follow the printed login URL. Expanded from
  # gaming-only to laptop + natalie-laptop on 2026-08-18; manual per-host
  # auth was deliberately kept (not an authKeyFile via sops-nix) — still
  # just 3 ad-hoc hosts, not a scale where automated auth pays for itself.
  services.tailscale.enable = true;
}
