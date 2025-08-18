{
  description = "Bosko's NixOS Flake";

  inputs = {
    # nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    bosko.url = "github:CommanderBosko/NixOS?ref=main";
  };

  outputs = { self, nixpkgs, bosko, ... }@inputs: {
    nixosConfigurations.venom = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux"; # don't forget this
      specialArgs = { inherit inputs; };
      modules = [
        "${bosko}/dotfiles/venom/bootloader.nix"
        "${bosko}/dotfiles/venom/enviornment.nix"
        "/etc/nixos/hardware-configuration.nix"
        "${bosko}/dotfiles/venom/networking.nix"
        "${bosko}/dotfiles/venom/nvidia.nix"
        "${bosko}/dotfiles/venom/users.nix"
        "${bosko}/dotfiles/venom/virtualisation.nix"
      ];
    };
  };
}
