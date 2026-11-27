# pi-hole — the household DNS appliance: Raspberry Pi 4B (aarch64, 1 GB RAM,
# wired Ethernet), Pi-hole v6 (FTL) with a local recursive unbound.
#
# Same shape as famdash (hosts/famdash/): stock sd-image-aarch64 via the shared
# modules/pi-sd-image.nix, booted from an image built on gaming, never rebuilt
# on-device (1 GB is too little). The Pi-hole and unbound services live in
# ./pihole.nix, the declarative groups and clients in ./clients.nix. This file
# keeps only what makes the box this box: its address, DNS wiring and secrets.
{ config, hostsData, lib, pkgs, ... }:

{
  imports = [
    ../../modules/pi-sd-image.nix
    ./pihole.nix
    ./clients.nix
  ];

  # Frozen at this machine's install-time NixOS release — never bump on upgrades
  system.stateVersion = "26.11";

  image.baseName = "pi-hole";

  # Fixed LAN address. Every client's DNS setting points at this address and the
  # router has no DHCP reservation (Xfinity gateway, same as gaming), so a
  # drifting lease would take DNS down for the whole house: pin it declaratively.
  # The profile deliberately has no interface-name, because the Pi 4's wired
  # NIC is eth0 on Raspberry Pi OS but probably end0 here (unverified until
  # first boot) and this host has only one Ethernet device. The address comes
  # from .claude/hosts.json (the router keeps .19 free of its own DHCP pool).
  networking.networkmanager.ensureProfiles.profiles.pi-hole-lan = {
    connection = {
      id = "pi-hole-lan";
      type = "ethernet";
      autoconnect = true;
    };
    ipv4 = {
      method = "manual";
      address1 = "${hostsData.hosts.pi-hole.ip}/24,10.0.0.1";
    };
    ipv6.method = "auto";
  };

  # The shared module points DNS at pi-hole's Tailscale IP, which here is THIS
  # box, so a cold boot would wait on an address nothing serves yet. Ask
  # ourselves first and fall back to Cloudflare, so the first gravity download
  # and tailscaled's control-plane lookup work before FTL is up.
  networking.nameservers = lib.mkForce [ "127.0.0.1" "1.1.1.1" ];

  # Tailscale must not rewrite resolv.conf to its MagicDNS resolver: the tailnet's
  # global nameserver IS this host, so that would route our own lookups out and
  # back through ourselves. The node's identity (name, 100.92.242.60 and its role
  # as the tailnet nameserver) comes from tailscaled.state copied onto the card.
  services.tailscale.extraSetFlags = [ "--accept-dns=false" ];

  # DNS from the LAN and the tailnet, plus the admin UI/API (FTL's own NTP port
  # stays closed: chrony sets the clock). The Pi has no other network, so these
  # are opened on every interface rather than guessing the wired NIC's name.
  services.pihole-ftl = {
    openFirewallDNS = true;
    openFirewallWebserver = true;
  };

  # Secrets. The web password hash is the live one (the same password keeps
  # working); the client list holds personal device names and MACs, which must
  # not sit in this public repo.
  sops.secrets."pihole-web-env" = {
    sopsFile = ../../secrets/hosts/pi-hole.yaml;
    restartUnits = [ "pihole-ftl.service" ];
  };
  # pihole-clients.service reads this through LoadCredential (as root), so the
  # file stays root-only.
  sops.secrets."pihole-clients" = {
    sopsFile = ../../secrets/hosts/pi-hole.yaml;
    restartUnits = [ "pihole-clients.service" ];
  };
  piHole.webEnvFile = config.sops.secrets."pihole-web-env".path;
  piHole.clients.file = config.sops.secrets."pihole-clients".path;

  # The pihole-api skill authenticates with Pi-hole's CLI password
  # (/etc/pihole/cli_pw, pihole:pihole 0600). This lets bosko read that one file
  # as root without a sudo password, and nothing else: the rule names the exact
  # command and its argument, so every other sudo still asks. It replaces the
  # blanket passwordless sudo the old Pi OS box had (user decision 2026-11-27).
  # The cost: whoever holds bosko's SSH key can call the Pi-hole API (lists,
  # blocking) without a sudo password.
  security.sudo.extraRules = [
    {
      users = [ "bosko" ];
      commands = [
        {
          command = "/run/current-system/sw/bin/cat /etc/pihole/cli_pw";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];

  environment.systemPackages = with pkgs; [
    dnsutils # dig, for checking the resolver by hand
    jq # the pihole-api skill parses API responses with it
    tmux
  ];
}
