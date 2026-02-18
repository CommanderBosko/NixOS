{ config, pkgs, inputs, self, ... }:

{
  home-manager.users.bosko = import "${self}/dotfiles/common/configs/home.nix";
  home-manager.users.natty = import "${self}/dotfiles/common/configs/home.nix";

  home-manager.extraSpecialArgs = { inherit inputs self; };
}