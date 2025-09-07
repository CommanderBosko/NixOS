{ config, pkgs, ... }:

{
  boot = {
    kernelPackages = pkgs.linuxPackages_zen;

    loader = {
      grub = {
        enable = true;
        efiSupport = true;
        useOSProber = true;
        devices = [ "nodev" ];
      };

      efi = {
        canTouchEfiVariables = true;
        efiSysMountPoint = "/boot";  # or "/boot/efi" if that’s your ESP
      };
    };
  };
}
