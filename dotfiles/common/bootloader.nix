{ config, pkgs, ... }:

{
  boot = {
    kernelPackages = pkgs.linuxPackages_zen;

    loader = {
      grub = {
        enable = true;
        efiSupport = true;
        efiInstallAsRemovable = true; # fallback EFI boot
        useOSProber = true;           # detect Windows/Linux
        device = "nodev";             # don't tie to a specific disk
      };
    };
  };
}
