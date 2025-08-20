{ config, pkgs, ... }:

{
  boot = {
    kernelPackages = pkgs.linuxPackages_zen;

    loader = {
      grub = {
        enable = true;
        efiSupport = true;
        efiInstallAsRemovable = true;
        useOSProber = true;
        device = "nodev";
      };
    };
  };
}
