{ config, inputs, pkgs, self, ... }:

{
  imports = [ inputs.home-manager.nixosModules.home-manager ];

  home-manager = {
    useGlobalPkgs     = true;
    useUserPackages   = true;
    extraSpecialArgs  = { inherit inputs self; };

    users.bosko = import "${self}/dotfiles/common/configs/home.nix";
    users.natty = import "${self}/dotfiles/common/configs/home.nix";
  };
}
