# Remote hosts declare their own bootloader: modules/bootloader.nix (GRUB + zen
# kernel) is desktop-only, so nothing is inherited from commonModules. The
# systemd-boot block below suits aarch64/EFI hosts (e.g. Oracle ARM); for an
# x86_64 BIOS host use GRUB instead.
{ pkgs, ... }:

{
  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
  };

  # Frozen at this machine's install-time NixOS release — never bump on upgrades
  system.stateVersion = "<current-nixos-release>";

  # hostName is set from the flake attribute name (see mkSystem). SSH hardening
  # (ssh.nix) comes from commonModules and opens port 22 itself.
  networking.firewall.enable = true;

  services.journald.extraConfig = "SystemMaxUse=200M";

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 7d";
    persistent = true;
  };

  environment.systemPackages = with pkgs; [
    tmux
  ];
}
