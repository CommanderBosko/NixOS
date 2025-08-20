{ config, pkgs, ... }:

{
  # Bootloader.
  boot = {
    kernelPackages = pkgs.linuxPackages_zen;
    loader = {
      grub = {
        enable = true;
        device = "/dev/nvme0n1";
        useOSProber = true;
      };
    };
  };
}
