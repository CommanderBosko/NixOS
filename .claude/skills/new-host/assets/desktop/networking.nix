{ ... }:

{
  # Shared desktop networking (NetworkManager, DNS, firewall, chrony, SSH)
  # lives in modules/desktop-networking.nix; hostName is set from the flake
  # attribute name. Only host-specific networking belongs here.
}
