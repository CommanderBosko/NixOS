{ pkgs, inputs, ... }:

let
  # Periodic watchdog for vpn-server + gaming's own WireGuard tunnel. Reuses
  # the existing vpn-status.sh (peer-status classification, hosts.json
  # resolution) rather than re-implementing WG parsing here. Catches hard
  # failures — server unreachable, tunnel offline, failed systemd units on
  # vpn-server — NOT subtle packet loss like the MTU black-hole bug (see
  # memory project_vpn_server_mtu_fix), which doesn't surface as a discrete
  # failure event and needs no watchdog now that it's fixed.
  vpnHealthCheck = pkgs.writeShellApplication {
    name = "vpn-health-check";
    runtimeInputs = [ pkgs.openssh pkgs.libnotify ];
    text = ''
      STATUS_OUTPUT=""
      if ! STATUS_OUTPUT=$(bash /home/bosko/NixOS/.claude/skills/vpn-status/scripts/vpn-status.sh 2>&1); then
        notify-send -u critical "VPN Server Unreachable" "vpn-status check failed: ''${STATUS_OUTPUT}"
        exit 0
      fi

      GAMING_LINE=$(grep '^gaming' <<< "$STATUS_OUTPUT" || true)
      if [[ -z "$GAMING_LINE" ]]; then
        notify-send -u critical "VPN Health Check" "Could not find gaming's row in vpn-status output."
        exit 0
      fi

      if [[ "$GAMING_LINE" != *Active* ]]; then
        notify-send -u critical "VPN Tunnel Down" "gaming's WireGuard tunnel: ''${GAMING_LINE}"
      fi

      FAILED_UNITS=$(ssh -o ConnectTimeout=10 -o BatchMode=yes bosko@150.136.232.63 \
        'systemctl --failed --plain --no-legend' 2>/dev/null || true)
      if [[ -n "$FAILED_UNITS" ]]; then
        notify-send -u critical "vpn-server: Failed Units" "''${FAILED_UNITS}"
      fi
    '';
  };
in
{
  # Frozen at this machine's install-time NixOS release — never bump on upgrades
  system.stateVersion = "25.11";

  # Services
  services = {
    # Display manager settings
    displayManager = {
      autoLogin.enable = false;
    };
  };

  # Hardware
  hardware = {
    # Bluetooth settings
    bluetooth = {
      enable = false;
      powerOnBoot = false;
      settings.General = {
        Enable = "Source,Sink,Media,Socket";
        Experimental = true;
      };
    };

    # Enable graphical interface
    graphics.enable = true;
  };

  # Enable aarch64 emulation so this machine can build for vpn-server (Oracle ARM)
  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];
  nix.settings.extra-platforms = [ "aarch64-linux" ];

  # This board's BIOS (ASRock X570 Phantom Gaming 4, P3.40) reports zeroed
  # CPPC frequency tables, so amd_pstate fails to probe every boot and spams
  # the kernel log (falls back to acpi-cpufreq anyway). Skip the failed probe.
  boot.kernelParams = [ "amd_pstate=disable" ];

  # Programs
  programs = {
    # Shell aliases
    zsh.shellAliases = {
      rift = "~/Rift/bin/rift";
    };
  };

  # Host-specific packages, on top of the shared modules/desktop-apps.nix list
  environment.systemPackages = with pkgs; [
    inputs.financeguru.packages.${pkgs.stdenv.hostPlatform.system}.default
    element-desktop
    mumble
    obs-studio
    qbittorrent
    tmux
    tor-browser
  ];

  # Host-specific flatpaks, on top of the shared modules/desktop-apps.nix list
  services.flatpak.packages = [
    "com.albiononline.AlbionOnline" # Albion Online
  ];

  # VPN health-check watchdog (see vpnHealthCheck above) — gaming-only, since
  # that's the machine where the MTU stutter was actually noticed.
  home-manager.users.bosko.systemd.user.services.vpn-health-check = {
    Unit.Description = "Check vpn-server and gaming's WireGuard tunnel health";
    Service = {
      Type = "oneshot";
      ExecStart = "${vpnHealthCheck}/bin/vpn-health-check";
    };
  };

  home-manager.users.bosko.systemd.user.timers.vpn-health-check = {
    Unit.Description = "Periodic VPN health check";
    Timer = {
      OnBootSec = "5m";
      OnUnitActiveSec = "20m";
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
