{ config, inputs, pkgs, self, ... }:

{
  imports = [ inputs.home-manager.nixosModules.home-manager ];

  home-manager = {
    useGlobalPkgs     = true;
    useUserPackages   = true;
    extraSpecialArgs  = { inherit inputs self; };   # optional

    users.bosko = import "${self}/dotfiles/common/configs/home.nix";   # or ./home.nix, whatever structure you like
    users.natty = import "${self}/dotfiles/common/configs/home.nix";
  };
}
