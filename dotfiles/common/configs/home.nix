{ self, ... }:

{
  imports = [
    ./helix.nix
    ./ssh.nix
  ];

  home = {
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
  };
}
