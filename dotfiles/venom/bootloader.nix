{ config, lib, pkgs, ... }:

let
  # Detect if /boot exists and is a FAT32 partition (ESP)
  hasESP = lib.mkDefault (
    (config.fileSystems ? "/boot") &&
    (config.fileSystems."/boot".fsType or null) == "vfat"
  );
in
{
  boot = {
    kernelPackages = pkgs.linuxPackages_zen;

    loader.grub = {
      enable = true;
      useOSProber = true;

      # BIOS boot (always works on ext4 root, no ESP required)
      device = lib.mkIf (!hasESP) (builtins.elemAt (builtins.split "/" config.fileSystems."/".device) 2);

      # UEFI boot (only if /boot is vfat)
      efiSupport = lib.mkIf hasESP true;
      efiInstallAsRemovable = lib.mkIf hasESP true;
      device = lib.mkIf hasESP "nodev"; # don’t clobber MBR
    };
  };
}
