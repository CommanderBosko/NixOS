{ ... }:

{
  # Real data directory for the "shared" Samba share below. setgid (leading
  # "2" in the mode) makes new files/dirs created directly on gaming inherit
  # the "shared" group; Samba's own "force group"/"create mask"/"directory
  # mask" settings do the same for files written over the network from
  # laptop/natalie-laptop.
  systemd.tmpfiles.rules = [
    "d /srv/shared 2770 root shared -"
  ];

  services.samba = {
    enable = true;
    openFirewall = true;
    settings = {
      global = {
        workgroup = "WORKGROUP";
        "server string" = "gaming";
        "netbios name" = "gaming";
        security = "user";
        "guest account" = "nobody";
        "map to guest" = "bad user";
      };
      shared = {
        path = "/srv/shared";
        browseable = "yes";
        "read only" = "no";
        "guest ok" = "yes";
        "force group" = "shared";
        "create mask" = "0660";
        "directory mask" = "0770";
      };
    };
  };
}
