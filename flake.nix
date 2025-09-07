{
  description = "Bosko's NixOS Flake";

  inputs = {
    nixPkgsStable.url = "github:nixos/nixpkgs/nixos-25.05";
    nixPkgsUnstable.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixPkgsStable, nixPkgsUnstable, ... }@inputs:
  let
    # Configure system settings
    system = "x86_64-linux";
    host = "venom";
    username = "bosko";
  in
  {
    # Configure nix configurations
    nixosConfigurations = {
      # Gaming with KDE
      gaming = nixPkgsUnstable.lib.nixosSystem {
        specialArgs = {
          inherit inputs;
          inherit system;
          inherit username;
          inherit host;
        };

      modules = [
        "/etc/nixos/hardware-configuration.nix"
        "./dotfiles/common/amd.nix"
        "./dotfiles/common/bootloader.nix"
        "./dotfiles/common/nvidia.nix"
        "./dotfiles/common/users.nix"
        "./dotfiles/common/virtualisation.nix"
        "./dotfiles/gaming/enviornment.nix"
        "./dotfiles/gaming/networking.nix"
      ];
    };

      # Laptop
      laptop = nixPkgsStable.lib.nixosSystem {
        specialArgs = {
          inherit inputs;
          inherit system;
          inherit username;
          inherit host;
        };

        modules = [
          "/etc/nixos/hardware-configuration.nix"
          "./dotfiles/common/amd.nix"
          "./dotfiles/common/bootloader.nix"
          "./dotfiles/common/nvidia.nix"
          "./dotfiles/common/users.nix"
          "./dotfiles/common/virtualisation.nix"
          "./dotfiles/laptop/enviornment.nix"
          "./dotfiles/laptop/networking.nix"
        ];
      };
    };
  };
}
