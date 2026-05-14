{ inputs, self, ... }:

{
  home-manager = {
    users = {
      bosko = {
        home = {
          username = "bosko";
          homeDirectory = "/home/bosko";
          stateVersion = "25.11";
        };

        imports = [
          (import "${self}/dotfiles/common/configs/home.nix")
          (import "${self}/dotfiles/common/configs/bosko-claude.nix")
        ];
      };

      natty = {
        home = {
          username = "natty";
          homeDirectory = "/home/natty";
          stateVersion = "25.11";
        };

        imports = [
          (import "${self}/dotfiles/common/configs/home.nix")
        ];
      };
    };

    extraSpecialArgs = { inherit inputs self; };
  };
}
