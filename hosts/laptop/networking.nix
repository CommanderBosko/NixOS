{ ... }:

{
  # Shared desktop networking (NetworkManager, DNS, firewall, chrony, SSH)
  # lives in modules/desktop-networking.nix; hostName is set from the flake
  # attribute name. Only host-specific networking belongs here.

  # WireGuard VPN — client address for laptop
  networking.wg-quick.interfaces.wg0.address = [ "10.10.0.3/24" ];
}
