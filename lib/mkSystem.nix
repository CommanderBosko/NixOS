{ pkgs, modules, lib, specialArgs, ... }:
  pkgs.lib.nixosSystem {
    inherit specialArgs;
    system = specialArgs.system;
    modules = modules ++ [
      # Common modules applied to all systems
      ./../dotfiles/common/modules/nix.nix
      ./../dotfiles/common/modules/users.nix
      ./../dotfiles/common/modules/shell.nix

      # You can add more common modules here
    ];
  }
