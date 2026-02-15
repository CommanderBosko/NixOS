{ config, pkgs, ... }:

{
  boot = {
    # Boot with the zen kernel
    kernelPackages = pkgs.linuxPackages_zen;

    # Enable and configure grub
    loader = {
      grub = {
        enable = true;
        efiSupport = true;
        useOSProber = true;
        devices = [ "nodev" ];
      };

      # Enable UEFI support
      efi = {
        canTouchEfiVariables = true;
        efiSysMountPoint = "/boot"; # or "/boot/efi" if that’s your ESP
      };
    };
  };
}
