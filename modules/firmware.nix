{ lib, pkgs, ... }:

{
  # Enable fwupd
  services.fwupd.enable = true;

  # Note: fwupd reports "UEFI ESP partition not detected or configured" on gaming.
  # That's harmless here: the ESP (nvme0n1p1, MBR type 0x0c) isn't auto-detected,
  # but this board (ASRock X570) ships no firmware via LVFS, Secure Boot is off, and
  # the only updatable device (Samsung 870 EVO SSD) updates over ATA, not the capsule
  # path. fwupd's EspLocation/OverrideESPMountPoint keys don't override 2.x detection,
  # so no config workaround helps — left unset on purpose. Revisit only if this host
  # moves to GPT + Secure Boot or a board that's on LVFS.

  # Update cpu microcode — only available on x86 platforms
  hardware.cpu = lib.mkIf pkgs.stdenv.hostPlatform.isx86 {
    amd.updateMicrocode = true;
    intel.updateMicrocode = true;
  };
}
