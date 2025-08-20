{
  description = "Bosko's NixOS Flake";

  inputs = {
    nixpkgsStable.url = "github:nixos/nixpkgs/nixos-25.05";
    nixpkgsUnstable.url = "github:nixos/nixpkgs/nixos-unstable";
    bosko.url = "github:CommanderBosko/NixOS?ref=main";
  };

  outputs = { self, nixpkgsStable, nixpkgsUnstable, bosko, ... }@inputs:
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
          "${bosko}/dotfiles/gaming/bootloader.nix"
          "${bosko}/dotfiles/gaming/enviornment.nix"
          "/etc/nixos/hardware-configuration.nix"
          "${bosko}/dotfiles/gaming/networking.nix"
          "${bosko}/dotfiles/gaming/nvidia.nix"
          "${bosko}/dotfiles/gaming/users.nix"
          "${bosko}/dotfiles/gaming/virtualisation.nix"
        ];
      };
    };
  };
}
