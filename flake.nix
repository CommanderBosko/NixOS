{
  description = "Bosko's NixOS Flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs = {nixpkgs, ... } @ inputs:
  
  {
  	nixosConfigurations.venom = nixpkgs.lib.nixosSystem {
      specialArgs = { inherit inputs; };
  	  modules = [
  	  	./dotfiles/venom/bootloader.nix
  	  	./dotfiles/venom/enviornment.nix
  	  	./dotfiles/hardware-configuration.nix
  	  	./dotfiles/venom/networking.nix
  	  	./dotfiles/venom/nvidia.nix
  	  	./dotfiles/venom/users.nix
  	  	./dotfiles/venom/virtualisation.nix
  	  ];
  	};
  };
}
