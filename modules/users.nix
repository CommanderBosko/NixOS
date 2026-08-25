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

      packages = with pkgs; [
        claude-code
        mcp-nixos # MCP server backing the user-scope nixos server (registered in ~/.claude.json via bosko-claude.nix)
        tailscale-mcp # MCP server backing the user-scope tailscale server (registered in ~/.claude.json via bosko-claude.nix); package in pkgs/tailscale-mcp.nix, overlay in modules/nix.nix
      ]
      # rtk isn't in nixpkgs-25.11 (stable) yet, only unstable — vpn-server pins
      # stable, so guard on attribute existence rather than hardcoding it and
      # breaking that host's eval. Picks itself up automatically once a future
      # stable point-release backports the package.
      #
      # TEMPORARY (added 2026-07-24): rtk-0.43.0's checkPhase fails upstream —
      # `cargo test` runs with -D warnings and the rtk crate has dead-code
      # warnings that get promoted to hard errors, breaking the nixpkgs build
      # outright. This skips rtk's own test suite so the package still builds;
      # REMOVE this override once nixpkgs ships an rtk revision whose tests
      # pass cleanly (i.e. `nh os boot --dry` builds rtk without doCheck=false).
      ++ pkgs.lib.optional (pkgs ? rtk) (pkgs.rtk.overrideAttrs (_: { doCheck = false; })); # Claude Code token-optimizing Bash proxy (hook wired in claude-code.nix)
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

  nix.settings.trusted-users = [
    "root"
    "bosko"
    "natty"
  ];
}
