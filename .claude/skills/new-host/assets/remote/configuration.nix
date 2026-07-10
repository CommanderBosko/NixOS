# For aarch64 remote hosts only: commonModules sets GRUB + zen kernel (x86-only),
# so force systemd-boot and the default ARM kernel. OMIT this whole `boot` block
# for an x86_64 remote host.
{ pkgs, lib, ... }:

{
  # Bootloader override — commonModules sets up GRUB + zen kernel (x86-only).
  # For aarch64 hosts, force systemd-boot and the default ARM kernel instead.
  boot = {
    kernelPackages = lib.mkForce pkgs.linuxPackages;

    loader = {
      grub.enable = lib.mkForce false;
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
  };

  # Frozen at this machine's install-time NixOS release — never bump on upgrades
  system.stateVersion = "<current-nixos-release>";

  # hostName is set from the flake attribute name (see mkSystem)
  networking = {
    firewall = {
      enable = true;
      allowedTCPPorts = [ 22 ];
    };
  };

  services = {
    openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = false;
        PermitRootLogin = "no";
      };
    };

    journald.extraConfig = "SystemMaxUse=200M";
  };

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
