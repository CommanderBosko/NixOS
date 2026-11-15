{ ... }:

{
  # Host-specific networking only — the shared desktop setup lives in
  # modules/desktop-networking.nix.

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
    # Wake-on-LAN on a magic packet (sent by `wake-host gaming`). 64 is NM's
    # "magic" flag; keyfiles store this setting as an integer. Waking from
    # power-off also needs "PCIE Devices Power On" enabled and ErP disabled in
    # the BIOS, or the NIC has no power after shutdown.
    ethernet.wake-on-lan = 64;
    ipv4 = {
      method = "manual";
      address1 = "10.0.0.251/24,10.0.0.1";
    };
  };
}
