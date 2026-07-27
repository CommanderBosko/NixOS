{ ... }:

{
  # Shared desktop networking (NetworkManager, DNS, firewall, chrony, SSH)
  # lives in modules/desktop-networking.nix; hostName is set from the flake
  # attribute name. Only host-specific networking belongs here.

  # WireGuard VPN client address for full-tunnel routing (DNS set in shared vpn.nix)
  networking.wg-quick.interfaces.wg0.address = [ "10.10.0.4/24" ];

  # Do NOT auto-start the tunnel at boot on this host only. The full-tunnel
  # kill-switch route (table 51820, suppress_prefixlength 0) captures all
  # traffic — including chrony's own NTP retries — the instant wg-quick starts,
  # even before the WireGuard handshake completes. If this laptop's WiFi is
  # still associating at that moment, every packet (NTP included) vanishes
  # into the not-yet-negotiated tunnel with no fallback, and nothing recovers
  # until the tunnel is torn down manually (`vpn-off`). gaming/laptop haven't
  # shown this failure, so their autostart is left at the default; here VPN
  # stays manual via the vpn-on/vpn-off aliases (modules/shell.nix).
  networking.wg-quick.interfaces.wg0.autostart = false;

  # natty also logs in over SSH on this host — list option, merges with the
  # shared "bosko" entry from desktop-networking.nix
  services.openssh.settings.AllowUsers = [ "natty" ];
}
