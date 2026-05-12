{ inputs, self, ... }:

{
  home-manager.users.bosko = {
    imports = [
      (import "${self}/dotfiles/common/configs/home.nix")
      (import "${self}/dotfiles/common/configs/bosko-claude.nix")
    ];
  };

  home-manager.users.natty = {
    home.username = "natty";
    home.homeDirectory = "/home/natty";
    home.stateVersion = "25.11";
  };

  home-manager.extraSpecialArgs = { inherit inputs self; };
}
