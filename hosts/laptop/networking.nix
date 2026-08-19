{ ... }:

{
  # Shared desktop networking (NetworkManager, DNS, firewall, chrony, SSH)
  # lives in modules/desktop-networking.nix; hostName is set from the flake
  # attribute name. Only host-specific networking belongs here.

  # WireGuard VPN — client address for laptop
  # Commented out along with modules/vpn.nix (flake.nix) while vpn-server is
  # down (Oracle admin-disabled, 2026-08-18) — an address with no
  # privateKeyFile/peers would just fail as a systemd unit at boot. Re-add
  # alongside the flake.nix import once vpn-server is back.
  # networking.wg-quick.interfaces.wg0.address = [ "10.10.0.3/24" ];
}
