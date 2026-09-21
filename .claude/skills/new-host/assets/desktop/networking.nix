{ ... }:

{
  # Shared desktop networking (NetworkManager, DNS, firewall, chrony, SSH)
  # lives in modules/desktop-networking.nix; hostName is set from the flake
  # attribute name. Only host-specific networking belongs here.

  # WireGuard VPN: modules/vpn.nix (currently out of desktopModules, see
  # flake.nix) derives this host's wg0 address from its `vpnIp` in
  # .claude/hosts.json, so nothing needs setting here — register the host as a
  # peer via /new-peer and add `vpnIp` there. The sops secret in
  # secrets/hosts/<hostname>.yaml must exist before the first build either way
  # — see Step 8 of the new-host skill.
}
