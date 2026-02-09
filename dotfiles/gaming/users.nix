{ config, pkgs, ... }:

{
  # Definie users

  # Bosko
  users.users.bosko = {
    shell = pkgs.zsh;
    isNormalUser = true;
    description = "bosko";
    password = "password";
    extraGroups = [
      "audio"
      "kvm"
      "libvirtd"
      "lp"
      "networkmanager"
      "video"
      "wheel"
    ];

    packages = with pkgs; [ ];
  };

  # Natty
  users.users.natty = {
    shell = pkgs.zsh;
    isNormalUser = true;
    description = "natty";
    password = "password";
    extraGroups = [
      "audio"
      "kvm"
      "libvirtd"
      "lp"
      "networkmanager"
      "video"
      "wheel"
    ];

    packages = with pkgs; [ ];
  };

  nix.settings.trusted-users = [ "root" "bosko" "natty" ];
}
