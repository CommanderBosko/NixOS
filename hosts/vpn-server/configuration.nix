{ pkgs, lib, ... }:

{
  imports = [
    ./wireguard.nix
    ./oracle-keepalive.nix
  ];

  # Bootloader for Oracle Cloud ARM (aarch64 EFI, systemd-boot). The GRUB + zen
  # kernel setup in modules/bootloader.nix is desktop-only, so nothing is
  # inherited here; the default kernel is used (zen isn't reliably available
  # on ARM).
  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
  };

  # Frozen at this machine's install-time NixOS release — never bump on upgrades
  system.stateVersion = "25.11";

  # hostName is set from the flake attribute name (see mkSystem). SSH hardening
  # and port 22 come from modules/ssh.nix.
  networking.firewall.enable = true;

  # Root SSH access — needed to connect after nixos-anywhere installs NixOS.
  # Key-only login; password auth remains off.
  users.users.root.openssh.authorizedKeys.keys = [
    # gaming
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAhUXwMqe6Eu4PRrV6BcdYYk7yRYI3x0gq+liliNhOsy kurthoernig@gmail.com"
    # laptop
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIB/EGGwStXtv/iorgMcglJYQyGLxX/bB+2quIO36c7zm kurthoernig@gmail.com"
    # natalie-laptop
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHnENcEPt+wOxR2EAu3BAcCXwErGJ4KfiANdPZH3oZfc kurthoernig@gmail.com"
  ];

  # Oracle Cloud ARM kernel doesn't support the audit subsystem; disable the
  # auditd service to prevent it from failing on every boot.
  # security.nix sets auditd.enable = true via mkDefault; mkForce overrides here.
  security.auditd.enable = lib.mkForce false;

  # nixos-rebuild --use-remote-sudo SSHes as bosko and runs sudo non-interactively;
  # a password prompt would stall the deploy over a batch SSH session.
  security.sudo.wheelNeedsPassword = false;

  # security.nix (commonModules) appends audit=1 to kernelParams.  The Oracle
  # Cloud ARM kernel's broken audit subsystem floods kauditd on boot, causing
  # PAM D-Bus timeouts that drop the nixos-rebuild SSH session mid-deploy.
  # Appending audit=0 after audit=1 wins at boot (last value takes precedence)
  # without clobbering any other kernel params.
  boot.kernelParams = lib.mkAfter [ "audit=0" ];

  # Automatic cleanup
  services.journald.extraConfig = "SystemMaxUse=200M";

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 7d";
    persistent = true;
  };

  environment.systemPackages = with pkgs; [
    wireguard-tools
  ];
}
