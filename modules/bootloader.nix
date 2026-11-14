{ inputs, system, ... }:
# Lift (when a newer zen boots): delete kernelPkgs and the overlay below, restore
# `kernelPackages = pkgs.linuxPackages_zen`, and drop the nixpkgs-kernel input.

let
  # TEMPORARY: zen from the pinned nixpkgs-kernel input (7.2.10), not the main
  # nixpkgs' 7.3.4, which panics at boot on gaming (see the input's comment in
  # flake.nix). A separate instance rather than legacyPackages so allowUnfree
  # applies to the kernel set's nvidia modules. Lift: back to pkgs.linuxPackages_zen.
  kernelPkgs = import inputs.nixpkgs-kernel {
    inherit system;
    config.allowUnfree = true;
  };
in
{
  # The current nixpkgs' aggregateModules expects the kernel build to emit
  # modules.cer (module signing certs), which the older 7.2.10 kernel doesn't,
  # so the modules tree fails with "cp: cannot stat .../modules.cer". Use the
  # matching aggregator from the same pinned nixpkgs as the kernel.
  nixpkgs.overlays = [
    (_final: _prev: { inherit (kernelPkgs) aggregateModules; })
  ];

  boot = {
    # Boot with the zen kernel
    kernelPackages = kernelPkgs.linuxPackages_zen;

    # Extra kernel paramaters
    kernelParams = [
      "splash"
    ];

    # Enable and configure grub
    loader = {
      grub = {
        enable = true;
        efiSupport = true;
        useOSProber = true;
        devices = [ "nodev" ];
      };

      # Enable UEFI support
      efi = {
        canTouchEfiVariables = true;
        efiSysMountPoint = "/boot"; # or "/boot/efi" if that’s your ESP
      };
    };
  };
}
