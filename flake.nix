{
  description = "Bosko's NixOS Flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    bosko.url = "github:CommanderBosko/NixOS?ref=main";
  };

  outputs = { self, nixpkgs, bosko, ... }: {
    nixosConfigurations.venom = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        bosko.nixosModules.bootloader
        bosko.nixosModules.environment
        bosko.nixosModules.hardware
        bosko.nixosModules.networking
        bosko.nixosModules.nvidia
        bosko.nixosModules.users
        bosko.nixosModules.virtualisation
      ];
    };
  };
}
