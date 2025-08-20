{ config, pkgs, lib, ... }:

{
  boot = {
    kernelPackages = pkgs.linuxPackages_zen;

    loader.grub = {
      enable = true;
      efiSupport = true;
      device = "nodev";               # write to ESP, not MBR
      efiInstallAsRemovable = true;   # fallback path \EFI\BOOT\BOOTX64.EFI
      useOSProber = true;
    };
  };
}
