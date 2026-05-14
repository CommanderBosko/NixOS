{ inputs, self, ... }:

let
  stateVersion = "25.11";
in
{
  home-manager = {
    users = {
      bosko = {
        home = {
          username = "bosko";
          homeDirectory = "/home/bosko";
          stateVersion = stateVersion;
        };

        imports = [
          (import "${self}/dotfiles/common/configs/home.nix")
          (import "${self}/dotfiles/bosko/bosko-claude.nix")
        ];
      };

      natty = {
        home = {
          username = "natty";
          homeDirectory = "/home/natty";
          stateVersion = stateVersion;
        };

        imports = [
          (import "${self}/dotfiles/common/configs/home.nix")
        ];
      };
    };

    extraSpecialArgs = { inherit inputs self; };
  };
}
