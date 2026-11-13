{ pkgs, inputs, lib, config, ... }:

{
  # Frozen at this machine's install-time NixOS release — never bump on upgrades
  system.stateVersion = "25.11";

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
    qutebrowser
    rpi-imager
    simple-scan
  ];
}
