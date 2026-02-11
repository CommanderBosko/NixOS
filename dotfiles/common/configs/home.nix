{ config, pkgs, self, ... }:

{
  home = {
    # Set home-manager state version
    stateVersion = "25.11";   # ← do NOT change this later — read the comment in home-manager release notes

    # Packages
    packages = with pkgs; [
    ];


    # Copy over dotfiles

    # Kate
    file.".config/katerc" = {
      source = "${self}/dotfiles/common/configs/katerc";
      force = true;
    };

    # Kitty
    file.".config/kitty/kitty.conf" = {
      source = "${self}/dotfiles/common/configs/kitty.conf";
      force = true;
    };

    # Starship
    file.".config/starship.toml" = {
      source = "${self}/dotfiles/common/configs/starship.toml";
      force = true;
    };
  };
}
