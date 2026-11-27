# Shared base for the Raspberry Pi hosts that boot a stock sd-image-aarch64
# image (famdash, pi-hole): the card layout, firmware, shared networking and
# Tailscale, host metrics, and the small fixes every Pi needs. Host files keep
# only what differs (stateVersion, image name, links, services, firewall).
# Build a host's flashable image with:
#   nix build .#nixosConfigurations.<host>.config.system.build.sdImage
# (gaming builds it under QEMU: boot.binfmt.emulatedSystems in its environment.nix).
{ lib, modulesPath, pkgs, ... }:

{
  imports = [
    "${modulesPath}/installer/sd-card/sd-image-aarch64.nix"
    # Shared networking despite the name: NetworkManager, pi-hole DNS over
    # Tailscale with a 1.1.1.1 fallback, firewall, and chrony with literal-IP
    # NTP servers (the Pi has no RTC, so it boots in the past and hostname-based
    # NTP/TLS would deadlock). It also pins SSH AllowUsers to bosko.
    ./desktop-networking.nix
    ./tailscale.nix
    # Host metrics for gaming's Prometheus; port 9100 is open on tailscale0 only.
    ./node-exporter.nix
  ];

  # Onboard Wi-Fi (Broadcom CYW43455) and other firmware blobs.
  hardware.enableRedistributableFirmware = true;

  # Keep logs across the crashes and power cuts that already hit a Pi once
  # (volatile journald made the 2026-10-03 famdash outage cause unrecoverable);
  # capped so they do not wear out the SD card.
  services.journald.settings.Journal = {
    Storage = "persistent";
    SystemMaxUse = "200M";
  };

  # nixpkgs' sd-image unit that grows the root partition on first boot fails on
  # every device: util-linux 2.42 pads lsblk's MAJ:MIN column, so the partition
  # number reads '2  ' and sfdisk rejects it. Same steps as upstream, padding
  # stripped. The unit only runs while /nix-path-registration exists (first
  # boot), so a fresh flash is the only runtime test of this.
  systemd.services.expand-root-partition.script = lib.mkForce ''
    rootPart=$(${pkgs.util-linux}/bin/findmnt -n -o SOURCE /)
    bootDevice=$(${pkgs.util-linux}/bin/lsblk -npo PKNAME "$rootPart")
    partNum=$(${pkgs.util-linux}/bin/lsblk -npo MAJ:MIN "$rootPart" | ${pkgs.coreutils}/bin/tr -d '[:space:]' | ${pkgs.gawk}/bin/gawk -F: '{print $2}')

    echo ",+," | ${pkgs.util-linux}/bin/sfdisk -N"$partNum" --no-reread "$bootDevice"
    ${pkgs.parted}/bin/partprobe
    ${pkgs.e2fsprogs}/bin/resize2fs "$rootPart"
  '';

  # Small boards with no swap otherwise.
  zramSwap.enable = true;

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 7d";
    persistent = true;
  };
}
