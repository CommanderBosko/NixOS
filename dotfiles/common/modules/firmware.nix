{ config, lib, pkgs, ... }:

{
  # Enable fwupd
  services.fwupd = {
    enable = true;

    # fwupd 2.x auto-detects the ESP by partition type. gaming's ESP is a valid
    # FAT32 partition but carries the wrong type code (W95 FAT32, not "EFI System"),
    # so the UEFI capsule plugin can't auto-detect it and warns "UEFI ESP partition
    # not detected or configured". Point the plugin straight at the ESP mount.
    #
    # NOTE: this must live under uefiCapsuleSettings ([uefi_capsule] section). The
    # old [fwupd] EspLocation key is not consulted by the capsule plugin for its ESP.
    uefiCapsuleSettings.OverrideESPMountPoint = config.boot.loader.efi.efiSysMountPoint;
  };

  # Update cpu microcode — only available on x86 platforms
  hardware.cpu = lib.mkIf pkgs.stdenv.hostPlatform.isx86 {
    amd.updateMicrocode = true;
    intel.updateMicrocode = true;
  };
}
