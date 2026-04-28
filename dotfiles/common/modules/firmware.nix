{ lib, pkgs, ... }:

{
  # Enable fwupd
  services.fwupd = {
    enable = true;
    daemonSettings = {
      EspLocation = "/boot"; # or "/boot/efi" — whichever is your actual mount point for the ESP
    };
  };

  # Update cpu microcode — only available on x86 platforms
  hardware.cpu = lib.mkIf pkgs.stdenv.hostPlatform.isx86 {
    amd.updateMicrocode = true;
    intel.updateMicrocode = true;
  };
}
