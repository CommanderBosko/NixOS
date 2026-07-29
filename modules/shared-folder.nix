{ ... }:

{
  # Shared by hosts/gaming/samba-shared.nix (the Samba server, real data
  # lives in /srv/shared there) and modules/shared-folder-client.nix (the
  # CIFS client mount on laptop/natalie-laptop) — both reference this group
  # by name so either user can read/write the share on any of the 3 hosts.
  users.groups.shared = { };
}
