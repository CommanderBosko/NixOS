{ pkgs, config, ... }:

{
  users.users = {
    # Bosko
    bosko = {
      shell = pkgs.zsh;
      isNormalUser = true;
      description = "bosko";
      hashedPasswordFile = config.sops.secrets."bosko-hashedPassword".path;
      homeMode = "0700";
      createHome = true;
      extraGroups = [
        "audio"
        "input"
        "kvm"
        "libvirtd"
        "lp"
        "networkmanager"
        "render"
        "shared"
        "video"
        "wheel"
      ];

      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAhUXwMqe6Eu4PRrV6BcdYYk7yRYI3x0gq+liliNhOsy kurthoernig@gmail.com" # Desktop
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIB/EGGwStXtv/iorgMcglJYQyGLxX/bB+2quIO36c7zm kurthoernig@gmail.com" # Laptop
      ];
    };

    # Natty
    natty = {
      shell = pkgs.zsh;
      isNormalUser = true;
      description = "natty";
      hashedPasswordFile = config.sops.secrets."natty-hashedPassword".path;
      homeMode = "0700";
      createHome = true;
      extraGroups = [
        "audio"
        "input"
        "kvm"
        "libvirtd"
        "lp"
        "networkmanager"
        "render"
        "shared"
        "video"
        "wheel"
      ];

      openssh.authorizedKeys.keys = [
      ];

      packages = [ ];
    };
  };

  # Group behind the /srv/shared folder: the Samba server on gaming
  # (hosts/gaming/samba-shared.nix) and the CIFS client mount on laptop /
  # natalie-laptop (modules/shared-folder-client.nix) both reference it by
  # name, so either user can read/write the share on any of the 3 hosts.
  users.groups.shared = { };

  nix.settings.trusted-users = [
    "root"
    "bosko"
    "natty"
  ];
}
