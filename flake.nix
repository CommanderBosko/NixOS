{
  description = "Bosko's NixOS Flake";

  inputs = {
    nixPkgsStable.url = "github:nixos/nixpkgs/nixos-25.05";
    nixPkgsUnstable.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixPkgsStable, nixPkgsUnstable, ... }@inputs:
  let
    system = "x86_64-linux";
    host = "venom";
    username = "bosko";

    # Overlay definition (reusable for both stable & unstable)
    riftOverlay = final: prev: {
      rift = prev.callPackage ./dotfiles/gaming/rift.nix { };
    };
  in {
    nixosConfigurations = {
      # Gaming
      gaming = nixPkgsUnstable.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs system username host; };

        modules = [
          /etc/nixos/hardware-configuration.nix
          ./dotfiles/common/amd.nix
          ./dotfiles/common/bootloader.nix
          ./dotfiles/common/nvidia.nix
          ./dotfiles/common/users.nix
          ./dotfiles/common/virtualisation.nix
          ./dotfiles/gaming/environment.nix
          ./dotfiles/gaming/networking.nix
        ];

        pkgs = import nixPkgsUnstable {
          inherit system;
          config.allowUnfree = true;
          overlays = [ riftOverlay ];
        };
      };

      # Laptop
      laptop = nixPkgsStable.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs system username host; };

        modules = [
          /etc/nixos/hardware-configuration.nix
          ./dotfiles/common/bootloader.nix
          ./dotfiles/common/nvidia.nix
          ./dotfiles/common/users.nix
          ./dotfiles/common/virtualisation.nix
          ./dotfiles/laptop/environment.nix
          ./dotfiles/laptop/networking.nix
        ];

        pkgs = import nixPkgsStable {
          inherit system;
          config.allowUnfree = true;
          overlays = [ riftOverlay ];
        };
      };
    };
  };
}
