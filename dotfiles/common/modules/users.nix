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

    packages = with pkgs; [
      mumble
      vesktop
    ];
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

    packages = with pkgs; [
      chromium
      discord
      firefox
      gimp
    ];
  };

  nix.settings.trusted-users = [ "root" "bosko" "natty" ];
}
