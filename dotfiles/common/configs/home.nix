{ config, pkgs, self, ... }:

{
  home = {
    # Set home-manager state version
    stateVersion = "25.11";   # ← do NOT change this later — read the comment in home-manager release notes

    # Packages
    packages = with pkgs; [
    ];

    # Kate
    file.".config/katerc" = {
      source = "${self}/dotfiles/common/configs/katerc";
    };

    # Kitty
    file.".config/kitty/kitty.conf" = {
      source = "${self}/dotfiles/common/configs/kitty.conf";
    };

    # Starship
    file.".config/starship.toml" ={
      source = "${self}/dotfiles/common/configs/starship.toml";
    };
  };
}
