{
  description = "Bosko's NixOS Flake";

  inputs = {
    nixpkgsStable.url = "github:nixos/nixpkgs/nixos-25.05";
    nixpkgsUnstable.url = "github:nixos/nixpkgs/nixos-unstable";
    boskoRepo.url = "github:CommanderBosko/NixOS?ref=main";
  };

  outputs = { self, nixpkgsStable, nixpkgsUnstable, boskoRepo, ... }@inputs: {
    nixosConfigurations.venom = nixpkgsUnstable.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit inputs; };
      modules = [
        "${boskoRepo}/dotfiles/venom/bootloader.nix"
        "${boskoRepo}/dotfiles/venom/enviornment.nix"
        "/etc/nixos/hardware-configuration.nix"
        "${boskoRepo}/dotfiles/venom/networking.nix"
        "${boskoRepo}/dotfiles/venom/nvidia.nix"
        "${boskoRepo}/dotfiles/venom/users.nix"
        "${boskoRepo}/dotfiles/venom/virtualisation.nix"
      ];
    };
  };
}
