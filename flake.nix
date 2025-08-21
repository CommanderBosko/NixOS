{
  description = "Bosko's NixOS Flake";

  inputs = {
    nixpkgsStable.url = "github:nixos/nixpkgs/nixos-25.05";
    nixpkgsUnstable.url = "github:nixos/nixpkgs/nixos-unstable";
    boskoRepo.url = "github:CommanderBosko/NixOS?ref=main";
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
          "./dotfiles/common/bootloader.nix"
          "./dotfiles/common/networking.nix"
          "./dotfiles/common/nvidia.nix"
          "./dotfiles/common/virtualisation.nix"
          "./dotfiles/gaming/enviornment.nix"
          "./dotfiles/gaming/users.nix"
        ];
      };
    };
  };
}
