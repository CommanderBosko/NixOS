{ config, pkgs, system, ... }:

{
  # System
  system = {
    # Automatic updating
    autoUpgrade = {
      enable = true;
      dates = "daily";
      persistent = true;
    };
  };

  # Set max journal entries
  services.journald.extraConfig = ''
    SystemMaxUse=500M
  '';

  # Enable sudo for wheel group
  security.sudo = {
    enable = true;
    wheelNeedsPassword = true;
  };

  # Automatic cleanup
  nix.gc = {
    automatic = true;
    dates = "daily";
    options = "--delete-older-than 7d";
    persistent = true;
  };

  # Testing console font
  console.font = "CodeNewRoman Nerd Font Mono";

  # System packages
  environment.systemPackages = with pkgs; [
    gnupg
    netcat
    nmap
    openssl
    tmux
    traceroute
  ];
}
