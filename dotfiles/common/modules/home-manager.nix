{ config, inputs, pkgs, ... }:

{
  imports = [ inputs.home-manager.nixosModules.home-manager ];

  home-manager = {
    useGlobalPkgs     = true;
    useUserPackages   = true;
    extraSpecialArgs  = { inherit inputs; };   # optional

    users.bosko = import ../home/default.nix;   # or ./home.nix, whatever structure you like
  };

#   environment.systemPackages = with pkgs; [ home-manager ];
}
