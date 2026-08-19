{ ... }:

{
  # Shared desktop networking (NetworkManager, DNS, firewall, chrony, SSH)
  # lives in modules/desktop-networking.nix; hostName is set from the flake
  # attribute name. Only host-specific networking belongs here.

  # WireGuard VPN — client address for gaming
  # Commented out along with modules/vpn.nix (flake.nix) while vpn-server is
  # down (Oracle admin-disabled, 2026-08-18) — an address with no
  # privateKeyFile/peers would just fail as a systemd unit at boot. Re-add
  # alongside the flake.nix import once vpn-server is back.
  # networking.wg-quick.interfaces.wg0.address = [ "10.10.0.2/24" ];

  # Static LAN IP for the wired interface. No router-side DHCP reservation
  # is possible (Xfinity modem, no admin access), so the address is pinned
  # declaratively via a NetworkManager keyfile profile instead. DNS is left
  # out here — modules/desktop-networking.nix already sets nameservers
  # directly (networkmanager.dns = "none").
  networking.networkmanager.ensureProfiles.profiles."gaming-static" = {
    connection = {
      id = "gaming-static";
      type = "ethernet";
      interface-name = "enp4s0";
      autoconnect = true;
    };
    ipv4 = {
      method = "manual";
      address1 = "10.0.0.251/24,10.0.0.1";
    };
  };
}
