{ config, ... }:

{
  imports = [
    ./helix.nix
    ./kate.nix
    ./kitty.nix
    ./mimeapps.nix
    ./ssh.nix
  ];

  # GTK/icon theme (packages and selection) is defined in
  # modules/desktop-environments/niri.nix, not here.

  # Shared folder for natty and bosko (/srv/shared — served by
  # hosts/gaming/samba-shared.nix, mounted by modules/shared-folder-client.nix).
  # mkOutOfStoreSymlink points straight at the
  # real path instead of copying it into the nix store, since /srv/shared
  # is a mutable directory both users read/write at runtime.
  home.file."Shared".source = config.lib.file.mkOutOfStoreSymlink "/srv/shared";
}
