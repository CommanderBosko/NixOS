{
  description = "Bosko's NixOS Flake";

  inputs = {
    # Nix packages
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    # Home manager
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, ... }@inputs:

  let
    # Configure system settings
    system = "x86_64-linux";
    systemState = { system.stateVersion = "25.11"; };
  in

  {
    # Configure nix configurations
    nixosConfigurations = {

      # Gaming
      gaming = nixpkgs.lib.nixosSystem {
        specialArgs = { inherit inputs self system; };

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
        "${self}/dotfiles/common/modules/home-manager.nix"
        "${self}/dotfiles/common/modules/localisation.nix"
        "${self}/dotfiles/common/modules/nix.nix"
        "${self}/dotfiles/common/modules/nvidia.nix"
        "${self}/dotfiles/common/modules/shell.nix"
        "${self}/dotfiles/common/modules/users.nix"
        "${self}/dotfiles/common/modules/virtualisation.nix"
        "${self}/dotfiles/gaming/environment.nix"
        "${self}/dotfiles/gaming/networking.nix"
      ];
    };

      # Laptop
      laptop = nixpkgs.lib.nixosSystem {
        specialArgs = { inherit inputs self system; };

        modules = [
          systemState
          "/etc/nixos/hardware-configuration.nix"
          "${self}/dotfiles/common/modules/audio.nix"
          "${self}/dotfiles/common/modules/bootloader.nix"
          "${self}/dotfiles/common/modules/emulation.nix"
          "${self}/dotfiles/common/modules/firmware.nix"
          "${self}/dotfiles/common/modules/fonts.nix"
          "${self}/dotfiles/common/modules/gaming.nix"
          "${self}/dotfiles/common/modules/home-manager.nix"
          "${self}/dotfiles/common/modules/localisation.nix"
          "${self}/dotfiles/common/modules/nix.nix"
          "${self}/dotfiles/common/modules/nvidia.nix"
          "${self}/dotfiles/common/modules/shell.nix"
          "${self}/dotfiles/common/modules/users.nix"
          "${self}/dotfiles/common/modules/virtualisation.nix"
          "${self}/dotfiles/laptop/environment.nix"
          "${self}/dotfiles/laptop/networking.nix"
        ];
      };

      # Server
      server = nixpkgs.lib.nixosSystem {
        specialArgs = { inherit inputs self system; };

        modules = [
          systemState
          "/etc/nixos/hardware-configuration.nix"
          "${self}/dotfiles/common/modules/bootloader.nix"
          "${self}/dotfiles/common/modules/firmware.nix"
          "${self}/dotfiles/common/modules/fonts.nix"
          "${self}/dotfiles/common/modules/home-manager.nix"
          "${self}/dotfiles/common/modules/localisation.nix"
          "${self}/dotfiles/common/modules/nix.nix"
          "${self}/dotfiles/common/modules/shell.nix"
          "${self}/dotfiles/common/modules/users.nix"
          "${self}/dotfiles/server/environment.nix"
          "${self}/dotfiles/server/networking.nix"
        ];
      };
    };
  };
}
