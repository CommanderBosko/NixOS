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
        Hostname = "10.0.0.101";
        User = "bosko";
      };

      "laptop" = {
        Hostname = "10.0.0.227";
        User = "bosko";
      };

      "gaming" = {
        Hostname = "10.0.0.251";
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
