{ config, pkgs, ... }:

{
  boot = {
    kernelPackages = pkgs.linuxPackages_zen;

    loader = {
      grub = {
        enable = true;
        efiSupport = true;
        useOSProber = true;        # change to false if NixOS-only
        devices = [ "nodev" ];     # must be a list
      };

      efi = {
        canTouchEfiVariables = true;
        efiSysMountPoint = "/boot";  # or "/boot/efi" if that’s your ESP
      };
    };
  };
}
