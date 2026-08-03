{ config, ... }:

# Pinchflat — self-hosted YouTube archiver (yt-dlp-backed), feeding the
# existing Jellyfin library on this host.
#
# Storage: writes into /mnt/media/YouTube on the shared media SSD (see
#          jellyfin-server.nix), sharing the same "media" group so Jellyfin's
#          scanner can read what Pinchflat downloads.
# Access:  LAN (enp4s0) + WireGuard (wg0) only, same scoping as Jellyfin.
# Setup:   channels/media profiles/output templates aren't declarative in the
#          nixpkgs module — configure those once through the web UI at
#          http://gaming:8945 after the first rebuild (use the built-in
#          "Media Center" profile preset, enable "Download NFO data" and
#          "Download Series Images", and add channels rather than playlists).
{
  services.pinchflat = {
    enable = true;
    mediaDir = "/mnt/media/YouTube";
    group = "media"; # joins Jellyfin's shared group instead of a standalone "pinchflat" group
    port = 8945;
    openFirewall = false; # scoped explicitly below
    secretsFile = config.sops.secrets."pinchflat-env".path;
  };

  sops.secrets."pinchflat-env".sopsFile = ../../secrets/hosts/gaming.yaml;

  # Matches the setgid/shared-group layout jellyfin-server.nix uses for
  # /mnt/media/{Movies,Shows,downloads}.
  systemd.tmpfiles.rules = [
    "d /mnt/media/YouTube 2775 bosko media -"
  ];

  networking.firewall.interfaces = {
    enp4s0.allowedTCPPorts = [ 8945 ];
    wg0.allowedTCPPorts = [ 8945 ];
  };
}
