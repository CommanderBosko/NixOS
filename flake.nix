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
  in
  {
    nixosConfigurations = {
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
        ];
      };
    };
  };
}
