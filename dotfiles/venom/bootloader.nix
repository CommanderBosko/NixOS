{ config, pkgs, lib, ... }:

{
  boot = {
    kernelPackages = pkgs.linuxPackages_zen;

    loader = {
      # Systemd-boot for UEFI systems
      systemd-boot.enable = lib.mkDefault true;
      efi.canTouchEfiVariables = lib.mkDefault true;

      # GRUB fallback for BIOS and tricky setups
      grub = {
        enable = lib.mkDefault true;
        version = 2;
        efiSupport = true;
        device = "nodev";  # UEFI installs
        efiInstallAsRemovable = true; # works even if EFI vars aren’t writable
        useOSProber = true;
      };
    };
  };

  # Auto-mount ESP at /boot if it exists, fallback gracefully if not
  fileSystems."/boot" = lib.mkIf (builtins.pathExists "/sys/firmware/efi") {
    device = "/dev/disk/by-partlabel/ESP"; # safer than /dev/sda1
    fsType = "vfat";
    options = [ "fmask=0077" "dmask=0077" ];
  };
}
