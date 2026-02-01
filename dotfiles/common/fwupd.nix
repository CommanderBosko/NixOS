{ config, pkgs, ... }:

{
  services.fwupd = {
    enable = true;
    daemonSettings = {
      EspLocation = "/boot";  # or "/boot/efi" — whichever is your actual mount point for the ESP
    };
  };
}
