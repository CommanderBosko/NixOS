{ ... }:

# Immich — self-hosted photo/video library — gaming host only.
#
# Storage:  the library lives in /mnt/media/Immich on the shared media SSD
#           (the mount is defined in jellyfin-server.nix; the root disk is too
#           full for photos). Owned immich:immich, mode 0700 — Jellyfin and the
#           media group deliberately cannot read it. mediaLocation can't be moved
#           safely after first start. Postgres (+ VectorChord) and Redis are
#           provisioned by the module itself; their data stays on the root disk.
#           Built-in DB dumps land in /mnt/media/Immich/backups.
# Access:   Tailscale only (tailscale0) — no LAN or internet exposure. Web UI and
#           mobile app server URL: http://100.66.15.1:2283 (see .claude/hosts.json).
# ML:       CPU only. The CUDA path needs an onnxruntime overlay + a long source
#           build (see reference_immich_nixos_research memory) — not worth it yet.
# Transcode: NVENC on the RTX 3070. Immich's ffmpeg is jellyfin-ffmpeg, the same
#           family Jellyfin already uses here. accelerationDevices applies to both
#           immich services; the NVENC toggle itself lives in the web UI
#           (Administration → Video Transcoding → Hardware acceleration → NVENC).
# Setup:    settings is left null (module default), so everything else is
#           configured in the web UI. After the first rebuild, open the URL
#           above and create the admin account. Server and mobile-app versions
#           must match.
# Backup:   none yet — the SSD is a single point of failure for the photos.
{
  services.immich = {
    enable = true;
    host = "0.0.0.0"; # reachable only through the tailscale0 firewall rule below
    port = 2283;
    openFirewall = false; # scoped explicitly below
    mediaLocation = "/mnt/media/Immich";

    # With PrivateDevices off, only these nodes are visible to the services.
    accelerationDevices = [
      "/dev/nvidia0"
      "/dev/nvidiactl"
      "/dev/nvidia-uvm"
      "/dev/nvidia-uvm-tools"
    ];
  };

  # Same GPU group access as jellyfin-server.nix. (The module only creates the
  # immich user itself; extraGroups merges in.)
  users.users.immich.extraGroups = [ "render" "video" ];

  # The module only chmods a custom mediaLocation (tmpfiles type "e"), it never
  # creates it. 00-nixos.conf sorts before the module's immich.conf, so this "d"
  # line wins over the duplicate path.
  systemd.tmpfiles.rules = [
    "d /mnt/media/Immich 0700 immich immich -"
  ];

  # /mnt/media is nofail: without this a missing SSD would let Immich write the
  # library into an empty directory on the (nearly full) root disk.
  systemd.services.immich-server.unitConfig.RequiresMountsFor = [ "/mnt/media" ];

  # Keep the first-import CPU-ML/thumbnail storm from stuttering games and
  # Jellyfin. The module runs both immich services in system-immich.slice.
  systemd.slices.system-immich.sliceConfig.CPUWeight = 20;

  # Tailscale only. (jellyfin-server.nix sets tailscale0 too; the lists merge.)
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 2283 ];
}
