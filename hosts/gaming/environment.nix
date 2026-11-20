{ pkgs, inputs, ... }:

{
  # Frozen at this machine's install-time NixOS release — never bump on upgrades
  system.stateVersion = "25.11";

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
    ethtool
    mumble
    obs-studio
    qbittorrent
    tmux
    tor-browser
    # Rift (EVE intel tool) shells out to these to check characters' online
    # status; it shows a "Missing dependency" popup without them. xprop is
    # already on the system via another package.
    wmctrl
    xwininfo
  ];

  # Lets bosko run `tailscale serve` without sudo (dev testing of Sidekick).
  services.tailscale.extraSetFlags = [ "--operator=bosko" ];

  # Host-specific flatpaks, on top of the shared modules/desktop-apps.nix list
  services.flatpak.packages = [
    "com.albiononline.AlbionOnline" # Albion Online
  ];
}
