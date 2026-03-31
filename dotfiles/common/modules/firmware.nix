{ ... }:

{
  # Enable fwupd
  services.fwupd = {
    enable = true;
    daemonSettings = {
      EspLocation = "/boot"; # or "/boot/efi" — whichever is your actual mount point for the ESP
    };
  };

  # Update cpu microcode
  hardware.cpu = {
    amd.updateMicrocode = true;
    intel.updateMicrocode = true;
  };
}
