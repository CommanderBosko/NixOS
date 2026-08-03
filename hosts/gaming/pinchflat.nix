{ config, pkgs, ... }:

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

  # modules/vpn.nix routes ALL of gaming's egress through the Oracle Cloud
  # VPS by design (full tunnel). YouTube flags that datacenter IP as bot
  # traffic ("Sign in to confirm you're not a bot"), breaking Pinchflat's
  # yt-dlp downloads. Exempt only Pinchflat's UID from the tunnel via a
  # policy-routing rule so its traffic exits via the normal LAN gateway
  # instead, while the rest of the host stays fully tunneled.
  networking.wg-quick.interfaces.wg0 = {
    postUp = ''
      PINCHFLAT_UID="$(${pkgs.coreutils}/bin/id -u pinchflat)"
      ${pkgs.iproute2}/bin/ip rule del uidrange "$PINCHFLAT_UID-$PINCHFLAT_UID" lookup main pref 100 2>/dev/null || true
      ${pkgs.iproute2}/bin/ip rule add uidrange "$PINCHFLAT_UID-$PINCHFLAT_UID" lookup main pref 100
    '';
    postDown = ''
      PINCHFLAT_UID="$(${pkgs.coreutils}/bin/id -u pinchflat)"
      ${pkgs.iproute2}/bin/ip rule del uidrange "$PINCHFLAT_UID-$PINCHFLAT_UID" lookup main pref 100 2>/dev/null || true
    '';
  };
}
