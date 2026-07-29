{ ... }:

{
  users.groups.shared = { };

  # Group-owned folder for natty and bosko to share files. setgid (leading
  # "2" in the mode) makes new files/dirs created inside inherit the
  # "shared" group instead of the creating user's primary group, so either
  # user can read/write anything the other adds without a manual chgrp.
  systemd.tmpfiles.rules = [
    "d /srv/shared 2770 root shared -"
  ];
}
