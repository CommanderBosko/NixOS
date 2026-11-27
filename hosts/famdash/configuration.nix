# famdash — family dashboard Raspberry Pi 4B (aarch64, headless, Wi-Fi only).
#
# Deliberately NOT the new-host skill's "remote" template: a Pi boots from an SD
# image (U-Boot + extlinux), not systemd-boot/EFI, and the sd-image-aarch64
# module declares the card layout itself, so there is no hardware-configuration.nix
# or disko.nix. Build the flashable image with:
#   nix build .#nixosConfigurations.famdash.config.system.build.sdImage
# (gaming builds it under QEMU: boot.binfmt.emulatedSystems in its environment.nix).
{ config, modulesPath, pkgs, ... }:

{
  imports = [
    "${modulesPath}/installer/sd-card/sd-image-aarch64.nix"
    # Shared networking despite the name: NetworkManager, pi-hole DNS over
    # Tailscale with a 1.1.1.1 fallback, firewall, and chrony with literal-IP
    # NTP servers (the Pi has no RTC, so it boots in the past and hostname-based
    # NTP/TLS would deadlock). It also pins SSH AllowUsers to bosko.
    ../../modules/desktop-networking.nix
    ../../modules/tailscale.nix
    ./famdash.nix
  ];

  # Frozen at this machine's install-time NixOS release — never bump on upgrades
  system.stateVersion = "26.11";

  image.baseName = "famdash";

  # Onboard Wi-Fi (Broadcom CYW43455) needs the redistributable firmware blobs.
  hardware.enableRedistributableFirmware = true;

  # Wi-Fi is the only link (eth0 is unplugged). The SSID and password stay out
  # of this public repo: they live in secrets/hosts/famdash.yaml as an env file
  # that NetworkManager substitutes into the profile at activation. Plain DHCP:
  # Tailscale (name famdash, 100.99.52.59) is the stable address, so a drifting
  # LAN lease does not matter.
  sops.secrets."famdash-wifi-env".sopsFile = ../../secrets/hosts/famdash.yaml;
  networking.networkmanager = {
    wifi.powersave = false;
    ensureProfiles = {
      environmentFiles = [ config.sops.secrets."famdash-wifi-env".path ];
      profiles.famdash-wifi = {
        connection = {
          id = "famdash-wifi";
          type = "wifi";
          interface-name = "wlan0";
          autoconnect = true;
        };
        wifi = {
          mode = "infrastructure";
          ssid = "$FAMDASH_WIFI_SSID";
        };
        wifi-security = {
          key-mgmt = "wpa-psk";
          psk = "$FAMDASH_WIFI_PSK";
        };
        ipv4.method = "auto";
      };
    };
  };

  # US regulatory domain, or the radio stays on the restrictive world default.
  hardware.wirelessRegulatoryDatabase = true;
  boot.extraModprobeConfig = "options cfg80211 ieee80211_regdom=US";

  # The dashboard has no auth, so it is reachable on the LAN and the tailnet
  # only; nothing else is opened (SSH comes from ssh.nix).
  networking.firewall.interfaces = {
    wlan0.allowedTCPPorts = [ 3000 ];
    tailscale0.allowedTCPPorts = [ 3000 ];
  };

  # Keep logs across the crashes and power cuts that already hit this Pi once
  # (volatile journald made the 2026-10-03 outage cause unrecoverable); capped
  # so they do not wear out the SD card.
  services.journald.settings.Journal = {
    Storage = "persistent";
    SystemMaxUse = "200M";
  };

  # 4 GB board with no swap otherwise.
  zramSwap.enable = true;

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 7d";
    persistent = true;
  };

  environment.systemPackages = with pkgs; [
    tmux
  ];
}
