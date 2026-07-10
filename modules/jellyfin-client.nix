{ pkgs, ... }:

# Jellyfin desktop client — installed on every desktop host (gaming, laptop,
# natalie-laptop) via desktopModules, so both bosko and natty can watch from a
# native app. The server itself runs only on gaming (hosts/gaming/jellyfin-server.nix).
{
  environment.systemPackages = [ pkgs.jellyfin-media-player ];
}
