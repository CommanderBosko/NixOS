{ ... }:

{
  # Shared desktop networking (NetworkManager, DNS, firewall, chrony, SSH)
  # lives in modules/desktop-networking.nix; hostName is set from the flake
  # attribute name. Only host-specific networking belongs here.

  # WireGuard VPN — client address for <hostname>. desktopModules imports
  # vpn.nix, so uncomment this once the host is registered as a peer via
  # /new-peer (the sops secret in secrets/hosts/<hostname>.yaml must exist
  # before the first build either way — see Step 8 of the new-host skill).
  # networking.wg-quick.interfaces.wg0.address = [ "10.10.0.<n>/24" ];
}
