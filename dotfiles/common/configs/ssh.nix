{ ... }:

{
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;

    settings = {
      "*" = {
        ServerAliveInterval = 60;
        ServerAliveCountMax = 3;
      };

      "natalie-laptop" = {
        # Tailscale IP, not the LAN address — this host is WiFi-only with no
        # static reservation, so its DHCP lease has already drifted once
        # (10.0.0.103 -> 10.0.0.101, see hosts.json/project-state.md).
        # Tailscale IPs are stable per-device, so this stops drifting
        # regardless of what the router hands out.
        Hostname = "100.116.208.93";
        User = "bosko";
      };

      "laptop" = {
        # Tailscale IP, not the LAN address — same WiFi-only/no-reservation
        # drift risk as natalie-laptop.
        Hostname = "100.114.0.106";
        User = "bosko";
      };

      "gaming" = {
        # Tailscale IP, not the LAN address — gaming's 10.0.0.251 is a
        # static NM reservation so it doesn't drift, but the Tailscale IP
        # also resolves when off the home LAN (same reasoning as
        # shared-folder-client.nix's mount fix), so use it here too for
        # consistency with the rest of this file.
        Hostname = "100.66.15.1";
        User = "bosko";
      };

      "pi-hole" = {
        # Tailscale IP, not the LAN address — pi-hole's DHCP lease has
        # drifted twice after power outages (10.0.0.19/.20/.21 history, see
        # hosts.json). Tailscale IPs are stable per-device, so this stops
        # drifting regardless of what the router hands out.
        Hostname = "100.92.242.60";
        User = "bosko";
      };

      "famdash" = {
        # Tailscale IP, not the LAN address — same DHCP-drift history as
        # pi-hole (10.0.0.20/.21, see hosts.json).
        Hostname = "100.99.52.59";
        User = "natty";
      };
    };
  };
}
