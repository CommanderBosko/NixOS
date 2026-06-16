{ ... }:

# Jellyfin media server — gaming host only (this is the host with the media SSD).
#
# Storage:  the spare Samsung SSD 870 EVO 1TB (/dev/sda) is wiped and reformatted
#           ext4, mounted at /mnt/media, pinned by UUID (see the fileSystems block
#           below — filled in AFTER the one-time GParted format).
# Access:   LAN (enp4s0) + WireGuard (wg0) only. No public/internet-facing ports.
# Transcode: NVIDIA NVENC on the RTX 3070 — the jellyfin user is added to the
#           render/video groups so jellyfin-ffmpeg can reach /dev/nvidia*.
#           (The actual NVENC toggle lives in the Jellyfin web dashboard:
#            Dashboard → Playback → Hardware acceleration → NVENC.)
{
  services.jellyfin = {
    enable = true;
    openFirewall = false; # we scope the ports to trusted interfaces below
  };

  # GPU access for hardware transcoding (NVENC/NVDEC).
  users.users.jellyfin.extraGroups = [ "render" "video" "media" ];

  # Shared media group so files dropped in by hand (as bosko/natty) stay
  # readable by the jellyfin scanner, and vice-versa.
  users.groups.media = { };
  users.users.bosko.extraGroups = [ "media" ];
  users.users.natty.extraGroups = [ "media" ];

  # Firewall — Jellyfin reachable only on the LAN and WireGuard interfaces.
  #   8096/tcp  — Jellyfin HTTP web UI / API
  #   1900/udp  — DLNA/SSDP discovery (lets Chromecast/Roku/TVs find the server)
  #   7359/udp  — Jellyfin client auto-discovery on the LAN
  networking.firewall.interfaces = {
    enp4s0 = {
      allowedTCPPorts = [ 8096 ];
      allowedUDPPorts = [ 1900 7359 ];
    };
    wg0.allowedTCPPorts = [ 8096 ];
  };

  # Media drive — the Samsung SSD 870 EVO 1TB, formatted ext4, pinned by UUID.
  fileSystems."/mnt/media" = {
    device = "/dev/disk/by-uuid/f0163d13-e964-4bab-8e5f-dd881ab6a6a4";
    fsType = "ext4";
    options = [ "defaults" "nofail" ]; # nofail: a missing media disk won't block boot
  };

  # Library folder layout the Jellyfin scanner expects. setgid (2775) so new
  # files inherit the media group; owned by bosko so manual drops are writable.
  systemd.tmpfiles.rules = [
    "d /mnt/media        2775 bosko media - "
    "d /mnt/media/Movies 2775 bosko media - "
    "d /mnt/media/Shows  2775 bosko media - "
  ];
}
