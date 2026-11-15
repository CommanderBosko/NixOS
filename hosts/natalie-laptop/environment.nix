{ pkgs, inputs, lib, config, system, ... }:

let
  # zen 7.2.10 from the pinned nixpkgs-kernel input (see flake.nix). A separate
  # instance rather than legacyPackages so allowUnfree applies to the kernel
  # set's nvidia modules.
  kernelPkgs = import inputs.nixpkgs-kernel {
    inherit system;
    config.allowUnfree = true;
  };
in
{
  # Frozen at this machine's install-time NixOS release — never bump on upgrades
  system.stateVersion = "25.11";

  # Hold this host on zen 7.2.10 instead of modules/bootloader.nix's
  # pkgs.linuxPackages_zen (7.3.4). On 7.3.4-zen2 and on stable 6.18.63 the
  # Intel AX201 Wi-Fi firmware asserts at first load (iwlwifi "Microcode SW
  # error", "Failed to run INIT ucode: -5"): no networks, Tailscale never
  # rejoins. Same firmware blob, with or without btusb, pcie_aspm=off or
  # iwlwifi.power_save=0 — only zen 7.2.10 has booted Wi-Fi here (2026-11-15).
  # Laptop and gaming boot 7.3.4-zen2 fine. Root cause not found; revisit when a
  # newer zen is tried with the user at the machine (keep gen 118 as fallback).
  # Lift: delete kernelPkgs, the overlay, this line, and the nixpkgs-kernel input.
  # The current nixpkgs' aggregateModules expects the kernel build to emit
  # modules.cer, which 7.2.10 doesn't, so use the aggregator from the same pin.
  nixpkgs.overlays = [
    (_final: _prev: { inherit (kernelPkgs) aggregateModules; })
  ];
  boot.kernelPackages = lib.mkForce kernelPkgs.linuxPackages_zen;

  # Services
  services = {
    # Enable touchpad
    libinput.enable = true;
  };

  # Hardware
  hardware = {
    # Bluetooth settings
    bluetooth = {
      enable = true;
      powerOnBoot = false;
      settings.General = {
        Enable = "Source,Sink,Media,Socket";
        Experimental = true;
      };
    };

    # This machine's discrete GPU (PCI 10de:1c94, Pascal-era) predates the
    # GSP firmware the open kernel module requires — NVRM probe fails with
    # "not supported by open nvidia.ko" on every boot under modules/nvidia.nix's
    # default. Fall back to the proprietary closed module instead.
    nvidia.open = lib.mkForce false;

    # Pascal (MX350, 10de:1c94) has aged out of the .stable driver branch —
    # the 595.84 driver silently refuses to bind to it ("will ignore"),
    # leaving no nvidia kernel module loaded at all. Needs the 580.xx legacy
    # branch, which still supports Pascal.
    nvidia.package = lib.mkForce config.boot.kernelPackages.nvidiaPackages.legacy_580;
  };

  # Battery is worn (~66% of design capacity, mostly calendar aging) — cap
  # charging at 80% to slow further wear. ASUS firmware exposes the cap via
  # asus-nb-wmi; some units drop it across suspend, so re-apply on resume too.
  systemd.services.battery-charge-limit = {
    description = "Cap battery charge at 80%";
    wantedBy = [ "multi-user.target" "post-resume.target" ];
    after = [ "post-resume.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.runtimeShell} -c 'echo 80 > /sys/class/power_supply/BAT0/charge_control_end_threshold'";
    };
  };

  # Host-specific packages, on top of the shared modules/desktop-apps.nix list
  environment.systemPackages = with pkgs; [
    inputs.financeguru.packages.${pkgs.stdenv.hostPlatform.system}.default
    anki
    rpi-imager
    simple-scan
  ];
}
