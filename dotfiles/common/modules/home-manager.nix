{ inputs, self, ... }:

{
  home-manager.users.bosko = {
    imports = [ (import "${self}/dotfiles/common/configs/home.nix") ];
  };
  home-manager.users.natty = {
    imports = [ (import "${self}/dotfiles/common/configs/home.nix") ];
  };

  home-manager.extraSpecialArgs = { inherit inputs self; };
}
