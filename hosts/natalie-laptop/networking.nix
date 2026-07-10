{ ... }:

{
  # Shared desktop networking (NetworkManager, DNS, firewall, chrony, SSH)
  # lives in modules/desktop-networking.nix; hostName is set from the flake
  # attribute name. Only host-specific networking belongs here.

  # WireGuard VPN client address for full-tunnel routing (DNS set in shared vpn.nix)
  networking.wg-quick.interfaces.wg0.address = [ "10.10.0.4/24" ];

  # natty also logs in over SSH on this host — list option, merges with the
  # shared "bosko" entry from desktop-networking.nix
  services.openssh.settings.AllowUsers = [ "natty" ];
}
