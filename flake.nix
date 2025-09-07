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

    # Overlay only for gaming
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
          # Inject pkgs with Rift overlay
          ({ ... }: {
            nixpkgs = {
              inherit system;
              config.allowUnfree = true;
              overlays = [ riftOverlay ];
            };
          })

          /etc/nixos/hardware-configuration.nix
          ./dotfiles/common/amd.nix
          ./dotfiles/common/bootloader.nix
          ./dotfiles/common/nvidia.nix
          ./dotfiles/common/users.nix
          ./dotfiles/common/virtualisation.nix
          ./dotfiles/gaming/environment.nix
          ./dotfiles/gaming/networking.nix
        ];
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
      };
    };
  };
}
