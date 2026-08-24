{ pkgs, ... }:

{
  environment.systemPackages = [ pkgs.cifs-utils ];

  # mdns4_minimal (nsswitch) only resolves .local-suffixed names, and there's
  # no DNS record for the bare "gaming" hostname the mount below uses — so
  # without this, mount.cifs fails with "could not resolve address for
  # gaming" and the automount unit hits start-limit-hit. Uses gaming's
  # Tailscale IP (not the 10.0.0.251 LAN IP) so the share still resolves
  # over the tailnet when client and server aren't on the same LAN — matches
  # .claude/hosts.json's tailscaleIp; update here too if that ever drifts.
  networking.extraHosts = ''
    100.66.15.1 gaming
  '';

  # Mounts gaming's "shared" Samba share at the same /srv/shared path used
  # locally on gaming, so ~/Shared (dotfiles/common/configs/home.nix) can
  # point at one identical path on every host regardless of server/client
  # role. Guest auth (matches hosts/gaming/samba-shared.nix's "guest ok"),
  # translated client-side to root:shared 0770 so anyone in the local
  # "shared" group can read/write it. x-systemd.automount + nofail keep
  # boot from hanging or failing if gaming is off.
  #
  # x-systemd.mount-timeout=2 (found 2026-08-23, corrected 2026-08-24): this
  # is an *automount* — any stat() on /srv/shared (e.g. starship's prompt,
  # DMS's panel) blocks the calling process until the mount attempt
  # resolves. When gaming is off/unreachable over Tailscale, that stat
  # blocks for the full timeout on every single trigger — confirmed via
  # journalctl showing repeated "Got automount request ... triggered by
  # starship" entries each taking ~10s wall clock at the old default, which
  # read as the whole terminal freezing for ~5-10s on every keypress. 2s
  # keeps that stall short without affecting the success path (mount.cifs
  # resolves in well under 1s when gaming is actually up).
  #
  # NB: the option is "x-systemd.mount-timeout" (hyphenated) per
  # `man systemd.mount` — an earlier pass here used the unhyphenated
  # "x-systemd.mounttimeout", which fstab silently ignores rather than
  # erroring on, so it had zero effect (confirmed live: `systemctl show
  # srv-shared.mount` still reported the systemd default TimeoutUSec=1min
  # 30s, and journalctl kept showing ~10s stalls post-rebuild).
  fileSystems."/srv/shared" = {
    device = "//gaming/shared";
    fsType = "cifs";
    options = [
      "guest"
      "uid=0"
      "gid=shared"
      "file_mode=0770"
      "dir_mode=0770"
      "noperm"
      "x-systemd.automount"
      "noauto"
      "x-systemd.idle-timeout=300"
      "x-systemd.mount-timeout=2"
      "_netdev"
      "nofail"
    ];
  };
}
