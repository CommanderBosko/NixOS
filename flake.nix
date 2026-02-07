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
        "${self}/dotfiles/common/amd.nix"
        "${self}/dotfiles/common/audio.nix"
        "${self}/dotfiles/common/bootloader.nix"
        "${self}/dotfiles/common/firmware.nix"
        "${self}/dotfiles/common/fonts.nix"
        "${self}/dotfiles/common/localisation.nix"
        "${self}/dotfiles/common/nix.nix"
        "${self}/dotfiles/common/nvidia.nix"
        "${self}/dotfiles/common/steam.nix"
        "${self}/dotfiles/common/virtualisation.nix"
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
          "${self}/dotfiles/common/audio.nix"
          "${self}/dotfiles/common/bootloader.nix"
          "${self}/dotfiles/common/firmware.nix"
          "${self}/dotfiles/common/fonts.nix"
          "${self}/dotfiles/common/localisation.nix"
          "${self}/dotfiles/common/nix.nix"
          "${self}/dotfiles/common/nvidia.nix"
          "${self}/dotfiles/common/steam.nix"
          "${self}/dotfiles/common/virtualisation.nix"
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
          "${self}/dotfiles/common/audio.nix"
          "${self}/dotfiles/common/bootloader.nix"
          "${self}/dotfiles/common/firmware.nix"
          "${self}/dotfiles/common/fonts.nix"
          "${self}/dotfiles/common/localisation.nix"
          "${self}/dotfiles/common/nix.nix"
          "${self}/dotfiles/common/nvidia.nix"
          "${self}/dotfiles/common/steam.nix"
          "${self}/dotfiles/common/virtualisation.nix"
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
          "${self}/dotfiles/common/bootloader.nix"
          "${self}/dotfiles/common/firmware.nix"
          "${self}/dotfiles/common/localisation.nix"
          "${self}/dotfiles/common/nix.nix"
          "${self}/dotfiles/common/virtualisation.nix"
          "${self}/dotfiles/server/environment.nix"
          "${self}/dotfiles/server/networking.nix"
          "${self}/dotfiles/server/users.nix"
        ];
      };
    };
  };
}
