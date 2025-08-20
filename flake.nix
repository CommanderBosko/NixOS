{
  description = "Bosko's NixOS Flake";

  inputs = {
    nixpkgsStable.url = "github:nixos/nixpkgs/nixos-25.05";
    nixpkgsUnstable.url = "github:nixos/nixpkgs/nixos-unstable";
    bosko.url = "github:CommanderBosko/NixOS?ref=main";
  };

  outputs = { self, nixpkgsStable, nixpkgsUnstable, bosko, ... }@inputs: {
    nixosConfigurations.venom = nixpkgsUnstable.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit inputs; };
      modules = [
#         "${bosko}/dotfiles/venom/bootloader.nix"
        "${bosko}/dotfiles/venom/enviornment.nix"
#         "/etc/nixos/hardware-configuration.nix"
        "${bosko}/dotfiles/venom/networking.nix"
        "${bosko}/dotfiles/venom/nvidia.nix"
        "${bosko}/dotfiles/venom/users.nix"
        "${bosko}/dotfiles/venom/virtualisation.nix"
      ];
    };
  };
}
