{ lib, self, ... }:

let
  # .claude/hosts.json is the single source of truth for host addresses: every
  # host with a tailscaleIp gets an alias named after it, dialling that IP as
  # the user from the host's `ssh` field ("user@host").
  #
  # Tailscale IP rather than the LAN address: the LAN ones are DHCP leases that
  # have drifted (natalie-laptop, pi-hole, famdash — none has a reservation) or
  # are unreachable off the home LAN, while Tailscale IPs are stable per-device
  # and resolve from anywhere.
  hosts = (builtins.fromJSON (builtins.readFile "${self}/.claude/hosts.json")).hosts;

  hostBlocks = lib.mapAttrs (_: host: {
    Hostname = host.tailscaleIp;
    User = lib.head (lib.splitString "@" host.ssh);
  }) (lib.filterAttrs (_: host: host ? tailscaleIp) hosts);
in
{
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;

    settings = {
      "*" = {
        ServerAliveInterval = 60;
        ServerAliveCountMax = 3;
      };
    }
    // hostBlocks;
  };
}
