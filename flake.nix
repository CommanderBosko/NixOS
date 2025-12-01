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
  in
  {
    # Configure nix configurations
    nixosConfigurations = {
      gaming = nixPkgsUnstable.lib.nixosSystem {
        specialArgs = {
          inherit inputs;
          inherit system;
        };

      modules = [
      	{
          system.stateVersion = "25.11";
      	}
        "/etc/nixos/hardware-configuration.nix"
        "${self}/dotfiles/common/amd.nix"
        "${self}/dotfiles/common/bootloader.nix"
        "${self}/dotfiles/common/nvidia.nix"
        "${self}/dotfiles/common/virtualisation.nix"
        "${self}/dotfiles/gaming/environment.nix"
        "${self}/dotfiles/gaming/networking.nix"
        "${self}/dotfiles/gaming/users.nix"
      ];
    };

      # Laptop
      laptop = nixPkgsUnstable.lib.nixosSystem {
        specialArgs = {
          inherit inputs;
          inherit system;
        };

        modules = [
          {
          	system.stateVersion = "25.11";
          }
          "/etc/nixos/hardware-configuration.nix"
          "${self}/dotfiles/common/amd.nix"
          "${self}/dotfiles/common/bootloader.nix"
          "${self}/dotfiles/common/nvidia.nix"
          "${self}/dotfiles/common/virtualisation.nix"
          "${self}/dotfiles/laptop/environment.nix"
          "${self}/dotfiles/laptop/networking.nix"
          "${self}/dotfiles/laptop/users.nix"
        ];
      };

      # Natalie
      natalie = nixPkgsUnstable.lib.nixosSystem {
        specialArgs = {
          inherit inputs;
          inherit system;
        };

        modules = [
          {
          	system.stateVersion = "25.11";
          }
          "/etc/nixos/hardware-configuration.nix"
          "${self}/dotfiles/common/amd.nix"
          "${self}/dotfiles/common/bootloader.nix"
          "${self}/dotfiles/common/nvidia.nix"
          "${self}/dotfiles/common/virtualisation.nix"
          "${self}/dotfiles/natalie/environment.nix"
          "${self}/dotfiles/natalie/networking.nix"
          "${self}/dotfiles/natalie/users.nix"
        ];
      };

      # Server
      server = nixPkgsStable.lib.nixosSystem {
        specialArgs = {
          inherit inputs;
          inherit system;
        };

        modules = [
          {
          	system.stateVersion = "25.11";
          }
          "/etc/nixos/hardware-configuration.nix"
          "${self}/dotfiles/common/bootloader.nix"
          "${self}/dotfiles/common/virtualisation.nix"
          "${self}/dotfiles/server/environment.nix"
          "${self}/dotfiles/server/networking.nix"
          "${self}/dotfiles/server/users.nix"
        ];
      };
    };
  };
}
