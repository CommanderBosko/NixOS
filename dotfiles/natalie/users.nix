{ config, pkgs, ... }:

{
  # Definie user
  users.users.natty = {
    shell = pkgs.zsh;
    isNormalUser = true;
    description = "natty";
    extraGroups = [
      "kvm"
      "libvirtd"
      "networkmanager"
      "wheel"
    ];

    packages = with pkgs; [ ];
  };

  nix.settings.trusted-users = [ "root" "natty" ];
}
