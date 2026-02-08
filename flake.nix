{
  description = "Bosko's NixOS Flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs, ... }@inputs:
  let
    # Configure system settings
    system = "x86_64-linux";
    systemState = { system.stateVersion = "25.11"; };
  in
  {
    # Configure nix configurations
    nixosConfigurations = {
      gaming = nixpkgs.lib.nixosSystem {
        specialArgs = {
          inherit inputs system;
        };

      modules = [
      	systemState
        "/etc/nixos/hardware-configuration.nix"
        "${self}/dotfiles/common/modules/amd.nix"
        "${self}/dotfiles/common/modules/audio.nix"
        "${self}/dotfiles/common/modules/bootloader.nix"
        "${self}/dotfiles/common/modules/emulation.nix"
        "${self}/dotfiles/common/modules/firmware.nix"
        "${self}/dotfiles/common/modules/fonts.nix"
        "${self}/dotfiles/common/modules/gaming.nix"
        "${self}/dotfiles/common/modules/localisation.nix"
        "${self}/dotfiles/common/modules/nix.nix"
        "${self}/dotfiles/common/modules/nvidia.nix"
        "${self}/dotfiles/common/modules/shell.nix"
        "${self}/dotfiles/common/modules/virtualisation.nix"
        "${self}/dotfiles/gaming/environment.nix"
        "${self}/dotfiles/gaming/networking.nix"
        "${self}/dotfiles/gaming/users.nix"
      ];
    };

      # Laptop
      laptop = nixpkgs.lib.nixosSystem {
        specialArgs = {
          inherit inputs system;
        };

        modules = [
          systemState
          "/etc/nixos/hardware-configuration.nix"
          "${self}/dotfiles/common/modules/audio.nix"
          "${self}/dotfiles/common/modules/bootloader.nix"
          "${self}/dotfiles/common/modules/emulation.nix"
          "${self}/dotfiles/common/modules/firmware.nix"
          "${self}/dotfiles/common/modules/fonts.nix"
          "${self}/dotfiles/common/modules/gaming.nix"
          "${self}/dotfiles/common/modules/localisation.nix"
          "${self}/dotfiles/common/modules/nix.nix"
          "${self}/dotfiles/common/modules/nvidia.nix"
          "${self}/dotfiles/common/modules/shell.nix"
          "${self}/dotfiles/common/modules/virtualisation.nix"
          "${self}/dotfiles/laptop/environment.nix"
          "${self}/dotfiles/laptop/networking.nix"
          "${self}/dotfiles/laptop/users.nix"
        ];
      };

      # Natalie
      natalie = nixpkgs.lib.nixosSystem {
        specialArgs = {
          inherit inputs system;
        };

        modules = [
          systemState
          "/etc/nixos/hardware-configuration.nix"
          "${self}/dotfiles/common/modules/audio.nix"
          "${self}/dotfiles/common/modules/bootloader.nix"
          "${self}/dotfiles/common/modules/emulation.nix"
          "${self}/dotfiles/common/modules/firmware.nix"
          "${self}/dotfiles/common/modules/fonts.nix"
          "${self}/dotfiles/common/modules/gaming.nix"
          "${self}/dotfiles/common/modules/localisation.nix"
          "${self}/dotfiles/common/modules/nix.nix"
          "${self}/dotfiles/common/modules/nvidia.nix"
          "${self}/dotfiles/common/modules/shell.nix"
          "${self}/dotfiles/common/modules/virtualisation.nix"
          "${self}/dotfiles/natalie/environment.nix"
          "${self}/dotfiles/natalie/networking.nix"
          "${self}/dotfiles/natalie/users.nix"
        ];
      };

      # Server
      server = nixpkgs.lib.nixosSystem {
        specialArgs = {
          inherit inputs system;
        };

        modules = [
          systemState
          "/etc/nixos/hardware-configuration.nix"
          "${self}/dotfiles/common/modules/bootloader.nix"
          "${self}/dotfiles/common/modules/firmware.nix"
          "${self}/dotfiles/common/modules/fonts.nix"
          "${self}/dotfiles/common/modules/localisation.nix"
          "${self}/dotfiles/common/modules/nix.nix"
          "${self}/dotfiles/common/modules/shell.nix"
          "${self}/dotfiles/common/modules/virtualisation.nix"
          "${self}/dotfiles/server/environment.nix"
          "${self}/dotfiles/server/networking.nix"
          "${self}/dotfiles/server/users.nix"
        ];
      };
    };
  };
}
