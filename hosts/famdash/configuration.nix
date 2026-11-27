# famdash — family dashboard Raspberry Pi 4B (aarch64, headless, Wi-Fi only).
#
# Deliberately NOT the new-host skill's "remote" template: a Pi boots from an SD
# image (U-Boot + extlinux), not systemd-boot/EFI, and the sd-image-aarch64
# module declares the card layout itself, so there is no hardware-configuration.nix
# or disko.nix. modules/pi-sd-image.nix is the shared Pi base (image, networking,
# journald, root-partition fix); this file keeps only what is famdash's own.
{ config, pkgs, ... }:

{
  imports = [
    ../../modules/pi-sd-image.nix
    ./famdash.nix
  ];

  # Frozen at this machine's install-time NixOS release — never bump on upgrades
  system.stateVersion = "26.11";

  image.baseName = "famdash";

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

  environment.systemPackages = with pkgs; [
    tmux
  ];
}
