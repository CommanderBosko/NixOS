{ pkgs, ... }:

{
  users.users = {
    # Bosko
    bosko = {
      shell = pkgs.zsh;
      isNormalUser = true;
      description = "bosko";
      hashedPassword = "***REDACTED-HASH***";
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
        "video"
        "wheel"
      ];

      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAhUXwMqe6Eu4PRrV6BcdYYk7yRYI3x0gq+liliNhOsy kurthoernig@gmail.com"
      ];

      packages = with pkgs; [
        claude-code
        gemini-cli
      ];
    };

    # Natty
    natty = {
      shell = pkgs.zsh;
      isNormalUser = true;
      description = "natty";
      hashedPassword = "***REDACTED-HASH***";
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
        "video"
        "wheel"
      ];

      openssh.authorizedKeys.keys = [
      ];
    };
  };

  nix.settings.trusted-users = [
    "root"
    "bosko"
    "natty"
  ];
}
