{
  description = "Bosko's NixOS Flake";

  inputs = {
#     nixpkgsStable.url = "github:nixos/nixpkgs/nixos-25.05";
    nixpkgsUnstable.url = "github:nixos/nixpkgs/nixos-unstable";
    bosko.url = "github:CommanderBosko/NixOS?ref=main";
  };

  outputs = { self, nixpkgsUnstable, bosko, ... }@inputs:
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
          "${bosko}/dotfiles/common/bootloader.nix"
          "${bosko}/dotfiles/common/networking.nix"
          "${bosko}/dotfiles/common/nvidia.nix"
          "${bosko}/dotfiles/common/virtualisation.nix"
          "${bosko}/dotfiles/gaming/enviornment.nix"
          "${bosko}/dotfiles/gaming/users.nix"
        ];
      };
    };
  };
}
