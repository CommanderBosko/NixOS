{ pkgs, ... }:

{
  # Definie users

  # Bosko
  users.users.bosko = {
    shell = pkgs.zsh;
    isNormalUser = true;
    description = "bosko";
    password = "password";
    homeMode = "0755";
    createHome = true;
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
    ];
  };

  # Natty
  users.users.natty = {
    shell = pkgs.zsh;
    isNormalUser = true;
    description = "natty";
    password = "password";
    homeMode = "0755";
    createHome = true;
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
      gimp
    ];
  };

  nix.settings.trusted-users = [
    "root"
    "bosko"
    "natty"
  ];
}
