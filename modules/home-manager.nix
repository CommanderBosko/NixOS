{ inputs, self, ... }:
{
  home-manager = {
    # Without this, HM activation hard-errors the moment a managed path
    # (e.g. gtk-3.0/settings.ini once niri.nix's `gtk.enable` claimed it,
    # 2026-08-09) collides with a real pre-existing file it didn't create
    # itself — refuses to guess whether to keep or discard it. Renaming the
    # loser to `<file>.backup` instead of failing means the same class of
    # collision self-heals on every future newly-managed path, across every
    # user, rather than needing a by-hand `mv`/delete each time it happens.
    backupFileExtension = "backup";

    users = {
      bosko = {
        home = {
          username = "bosko";
          homeDirectory = "/home/bosko";
          stateVersion = "25.11";
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
