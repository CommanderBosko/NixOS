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

    # Nix-Flatpaks
    nix-flatpak.url = "github:gmodena/nix-flatpak/?ref=latest";
  };

  outputs = { self, nixpkgs, home-manager, nix-flatpak, ... }@inputs:

  let
    # Configure system settings
    system = "x86_64-linux";
    systemState = { system.stateVersion = "25.11"; };
    forAllSystems = nixpkgs.lib.genAttrs [ system ];

    # Common modules applied to all systems
    commonModules = [
      systemState
      "${self}/dotfiles/common/modules/bootloader.nix"
      "${self}/dotfiles/common/modules/firmware.nix"
      "${self}/dotfiles/common/modules/fonts.nix"
      "${self}/dotfiles/common/modules/localisation.nix"
      "${self}/dotfiles/common/modules/nix.nix"
      "${self}/dotfiles/common/modules/shell.nix"
      "${self}/dotfiles/common/modules/users.nix"
    ];

    # Modules specific to desktop systems (gaming, laptop)
    desktopModules = commonModules ++ [
      nix-flatpak.nixosModules.nix-flatpak
      "${self}/dotfiles/common/modules/amd.nix"
      "${self}/dotfiles/common/modules/audio.nix"
      "${self}/dotfiles/common/modules/emulation.nix"
      "${self}/dotfiles/common/modules/gaming.nix"
      "${self}/dotfiles/common/modules/nvidia.nix"
      "${self}/dotfiles/common/modules/virtualisation.nix"
    ];

    # Modules specific to server systems
    serverModules = commonModules ++ [
      # Add any server-specific modules here if needed
    ];
    
  in
  {
    # Custom library functions (moved from lib/default.nix)
    lib = {
      mkSystem = { nixpkgs, modules, specialArgs, ... }:

      nixpkgs.lib.nixosSystem {
        inherit specialArgs;
        system = specialArgs.system;
        modules = modules ++ [
          # Common modules applied to all systems (copied from original lib/default.nix)
          "${self}/dotfiles/common/modules/nix.nix"
          "${self}/dotfiles/common/modules/users.nix"
          "${self}/dotfiles/common/modules/shell.nix"
          # You can add more common modules here
        ];
      };
    };

    # Configure nix configurations
    nixosConfigurations = {

      # Gaming
      gaming = self.lib.mkSystem {
        inherit inputs system nixpkgs;
        specialArgs = { inherit inputs self system; };
        modules = desktopModules ++ [
          # Machine-specific modules
          "${self}/dotfiles/gaming/hardware-configuration.nix"
          "${self}/dotfiles/gaming/environment.nix"
          "${self}/dotfiles/gaming/networking.nix"
        ];
      };

      # Laptop
      laptop = self.lib.mkSystem {
        inherit inputs system nixpkgs;
        specialArgs = { inherit inputs self system; };
        modules = desktopModules ++ [
          # Machine-specific modules
          "${self}/dotfiles/laptop/hardware-configuration.nix"
          "${self}/dotfiles/laptop/environment.nix"
          "${self}/dotfiles/laptop/networking.nix"
          "${self}/dotfiles/common/modules/desktop-environments/wayfire.nix"
        ];
      };

      # Server
      server = self.lib.mkSystem {
        inherit inputs system nixpkgs;
        specialArgs = { inherit inputs self system; };
        modules = serverModules ++ [
          # Machine-specific modules
          "${self}/dotfiles/server/hardware-configuration.nix"
          "${self}/dotfiles/server/environment.nix"
          "${self}/dotfiles/server/networking.nix"
        ];
      };
    };

    homeConfigurations = {
      # Home Manager for user 'bosko'
      bosko = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.${system};
        modules = [
          "${self}/dotfiles/common/configs/home.nix"
        ];
        extraSpecialArgs = { inherit inputs self; };
      };

      # Home Manager for user 'natty'
      natty = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.${system};
        modules = [
          "${self}/dotfiles/common/configs/home.nix"
        ];
        extraSpecialArgs = { inherit inputs self; };
      };
    };
  };
}
