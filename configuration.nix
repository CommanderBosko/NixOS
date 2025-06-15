{ config, pkgs, ... }:

{
  imports =
    [
      ./hardware-configuration.nix
      ./bootloader.nix
      ./enviornment.nix
      ./networking.nix
      ./users.nix
      ./nvidia.nix
    ];

  # Set NixOS Version
  system.stateVersion = "25.05";
}
