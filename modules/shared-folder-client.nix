{ pkgs, ... }:

{
  environment.systemPackages = [ pkgs.cifs-utils ];

  # Mounts gaming's "shared" Samba share at the same /srv/shared path used
  # locally on gaming, so ~/Shared (dotfiles/common/configs/home.nix) can
  # point at one identical path on every host regardless of server/client
  # role. Guest auth (matches hosts/gaming/samba-shared.nix's "guest ok"),
  # translated client-side to root:shared 0770 so anyone in the local
  # "shared" group can read/write it. x-systemd.automount + nofail keep
  # boot from hanging or failing if gaming is off.
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
      "x-systemd.mounttimeout=10"
      "_netdev"
      "nofail"
    ];
  };
}
