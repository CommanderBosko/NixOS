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
        "video"
        "wheel"
      ];

      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAhUXwMqe6Eu4PRrV6BcdYYk7yRYI3x0gq+liliNhOsy kurthoernig@gmail.com" # Desktop
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIB/EGGwStXtv/iorgMcglJYQyGLxX/bB+2quIO36c7zm kurthoernig@gmail.com" # Laptop
      ];

      packages = with pkgs; [
        claude-code
        gemini-cli
        mcp-nixos # MCP server backing the project-scoped nixos server in /home/bosko/NixOS/.mcp.json
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
        "video"
        "wheel"
      ];

      openssh.authorizedKeys.keys = [
      ];

      packages = with pkgs; [
        gemini-cli
      ];
    };
  };

  nix.settings.trusted-users = [
    "root"
    "bosko"
    "natty"
  ];
}
