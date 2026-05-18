{ ... }:

{
  # Disko disk layout for Oracle Cloud ARM VM (VM.Standard.A1.Flex)
  # Disk: /dev/sda, ~46.6G, UEFI boot
  # Labels must match hardware-configuration.nix: "boot" (EFI) and "nixos" (root)

  disko.devices = {
    disk.sda = {
      device = "/dev/sda";
      type = "disk";
      content = {
        type = "gpt";
        partitions = {
          ESP = {
            name = "ESP";
            size = "512M";
            type = "EF00"; # EFI System Partition
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              mountOptions = [ "defaults" ];
              extraArgs = [ "-n" "boot" ]; # label = "boot"
            };
          };
          root = {
            name = "root";
            size = "100%";
            content = {
              type = "filesystem";
              format = "ext4";
              mountpoint = "/";
              extraArgs = [ "-L" "nixos" ]; # label = "nixos"
            };
          };
        };
      };
    };
  };
}
