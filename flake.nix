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
        "${host}" = nixpkgsUnstable.lib.nixosSystem {
        specialArgs = {
          inherit inputs;
          inherit system;
          inherit username;
          inherit host;
        };
        modules = [
          "${bosko}/dotfiles/${host}/bootloader.nix"
          "${bosko}/dotfiles/${host}/enviornment.nix"
          "/etc/nixos/hardware-configuration.nix"
          "${bosko}/dotfiles/${host}/networking.nix"
          "${bosko}/dotfiles/${host}/nvidia.nix"
          "${bosko}/dotfiles/${host}/users.nix"
          "${bosko}/dotfiles/${host}/virtualisation.nix"
        ];
      };
    };
  };
}
