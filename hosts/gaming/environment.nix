{ pkgs, inputs, ... }:

{
  # Frozen at this machine's install-time NixOS release — never bump on upgrades
  system.stateVersion = "25.11";

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
      # Local LLM for Hermes Agent (on-demand; frees the GPU for games when off)
      llm-on = "sudo systemctl start llama-cpp";
      llm-off = "sudo systemctl stop llama-cpp";
      llm-status = "systemctl status llama-cpp --no-pager";
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

  # Lets bosko run `tailscale serve` without sudo (dev testing of Sidekick).
  services.tailscale.extraSetFlags = [ "--operator=bosko" ];

  # Host-specific flatpaks, on top of the shared modules/desktop-apps.nix list
  services.flatpak.packages = [
    "com.albiononline.AlbionOnline" # Albion Online
  ];
}
