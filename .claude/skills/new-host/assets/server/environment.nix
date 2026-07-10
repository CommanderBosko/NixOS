{ pkgs, ... }:

{
  # Frozen at this machine's install-time NixOS release — never bump on upgrades
  system.stateVersion = "<current-nixos-release>";

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

  # System packages
  environment.systemPackages = with pkgs; [
    tmux
  ];
}
