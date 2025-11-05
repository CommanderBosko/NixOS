{
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

  nix.settings.trusted-users = [ "bosko" "natty" ];
}
