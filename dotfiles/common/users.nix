{ config, pkgs, ... }:

{
  # Define a user account. Don't forget to set a password with ‘passwd’.
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

    # User specific packages
    packages = with pkgs; [
    ];
  };
}
