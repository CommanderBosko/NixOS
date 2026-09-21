{ ... }:

{
  # Host-specific networking only — the shared desktop setup lives in
  # modules/desktop-networking.nix.

  # natty also logs in over SSH on this host — list option, merges with the
  # shared "bosko" entry from desktop-networking.nix
  services.openssh.settings.AllowUsers = [ "natty" ];
}
