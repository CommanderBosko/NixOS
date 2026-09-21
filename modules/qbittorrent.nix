{ ... }:

# qBittorrent daemon with its Web UI — laptop and natalie-laptop. gaming
# installs the qbittorrent GUI package instead (hosts/gaming/environment.nix).
{
  # Enable Qbittorrent (Web UI bound to localhost only — H-6)
  services.qbittorrent = {
    enable = true;
    serverConfig = {
      Preferences = {
        WebUI = {
          Address = "127.0.0.1";
        };
      };
    };
  };
}
