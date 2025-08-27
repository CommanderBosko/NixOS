{
  description = "Bosko's NixOS Flake";

  inputs = {
    nixpkgsStable.url = "github:nixos/nixpkgs/nixos-25.05";
    nixpkgsUnstable.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgsStable, nixpkgsUnstable, ... }@inputs:
  let
    system = "x86_64-linux";
    host = "venom";
    username = "bosko";

    # Import nixpkgs for the package sets
#     pkgsStable = import nixpkgsStable { inherit system; config.allowUnfree = true; };
#     pkgsUnstable = import nixpkgsUnstable */{ inherit system; config.allowUnfree = true; };
  in
  {
    # Add non-nix packages
    packages.${system} = {
      rift = import ./dotfiles/gaming/rift.nix { pkgs = nixpkgsUnstable; };
    };

    # Configure nix configurations
    nixosConfigurations = {
      # Gaming with KDE
      gaming = nixpkgsUnstable.lib.nixosSystem {
        specialArgs = {
          inherit inputs;
          inherit system;
          inherit username;
          inherit host;
        };

      modules = [
        "/etc/nixos/hardware-configuration.nix"
        "${self}/dotfiles/common/bootloader.nix"
        "${self}/dotfiles/common/nvidia.nix"
        "${self}/dotfiles/common/users.nix"
        "${self}/dotfiles/common/virtualisation.nix"
        "${self}/dotfiles/gaming/enviornment.nix"
        "${self}/dotfiles/gaming/networking.nix"
        "${self}/dotfiles/gaming/rift.nix"
      ];
    };

      # Laptop
      laptop = nixpkgsStable.lib.nixosSystem {
        specialArgs = {
          inherit inputs;
          inherit system;
          inherit username;
          inherit host;
        };

        modules = [
          "/etc/nixos/hardware-configuration.nix"
          "${self}/dotfiles/common/bootloader.nix"
          "${self}/dotfiles/common/nvidia.nix"
          "${self}/dotfiles/common/users.nix"
          "${self}/dotfiles/common/virtualisation.nix"
          "${self}/dotfiles/laptop/enviornment.nix"
          "${self}/dotfiles/laptop/networking.nix"
        ];
      };
    };
  };
}
