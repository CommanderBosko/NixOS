{
  description = "Bosko's NixOS Flake";

  inputs = {
    nixpkgsStable.url = "github:nixos/nixpkgs/nixos-25.05";
    nixpkgsUnstable.url = "github:nixos/nixpkgs/nixos-unstable";
    boskoRepo.url = "github:CommanderBosko/NixOS?ref=main";
  };

  outputs = { self, nixpkgsStable, nixpkgsUnstable, boskoRepo ... }@inputs:
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
          "${boskoRepo}/dotfiles/common/bootloader.nix"
          "${boskoRepo}/dotfiles/common/networking.nix"
          "${boskoRepo}/dotfiles/common/nvidia.nix"
          "${boskoRepo}/dotfiles/common/virtualisation.nix"
          "${boskoRepo}/dotfiles/gaming/enviornment.nix"
          "${boskoRepo}/dotfiles/gaming/users.nix"
        ];
      };
    };
  };
}
