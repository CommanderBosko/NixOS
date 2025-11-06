{ config, pkgs, ... }:

{
  # Definie user
  users.users.bosko = {
    shell = pkgs.zsh;
    isNormalUser = true;
    description = "bosko";
    extraGroups = [
      "kvm"
      "libvirtd"
      "networkmanager"
      "wheel"
    ];

    packages = with pkgs; [ ];
  };

  nix.settings.trusted-users = [ "root" "bosko" ];
}
