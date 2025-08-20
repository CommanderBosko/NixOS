{ config, pkgs, lib, ... }:

let
  isUEFI = builtins.pathExists "/sys/firmware/efi";
in
{
  boot = {
    kernelPackages = pkgs.linuxPackages_zen;

    loader = {
      # Enable systemd-boot only on UEFI machines
      systemd-boot.enable = lib.mkIf isUEFI (lib.mkForce true);

      efi = {
        canTouchEfiVariables = lib.mkIf isUEFI true;
        efiSysMountPoint = "/boot";  # systemd-boot expects this
      };
    };

    # Optional niceties
    bootspec.enable = true;
    loader.timeout = 3;
    loader.systemd-boot.configurationLimit = 10;
  };

  # Mount the ESP at /boot by label to avoid hardcoding a disk path
  fileSystems."/boot" = lib.mkIf isUEFI {
    device = "/dev/disk/by-label/ESP";  # <-- universal; see steps below
    fsType = "vfat";
    options = [ "fmask=0077" "dmask=0077" ];
  };
}
