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

    # Import nixpkgs for the package sets
    pkgsStable = import nixPkgsStable { inherit system; config.allowUnfree = true; };
    pkgsUnstable = import nixPkgsUnstable { inherit system; config.allowUnfree = true; };
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
          rift = import ./dotfiles/gaming/rift.nix { pkgs = pkgsUnstable; };
        };

      modules = [
        "/etc/nixos/hardware-configuration.nix"
        "${self}/dotfiles/common/bootloader.nix"
        "${self}/dotfiles/common/nvidia.nix"
        "${self}/dotfiles/common/users.nix"
        "${self}/dotfiles/common/virtualisation.nix"
        "${self}/dotfiles/gaming/enviornment.nix"
        "${self}/dotfiles/gaming/networking.nix"
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
