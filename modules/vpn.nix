{ pkgs, config, hostsData, ... }:

let
  hostName = config.networking.hostName;
in
{
  # WireGuard client — shared peer/server config for gaming, laptop, natalie-laptop.
  #
  # Not imported by any host right now: Oracle admin-disabled the vpn-server
  # instance 2026-08-18, so the tunnel has no endpoint (Tailscale, modules/
  # tailscale.nix, is the stopgap). Re-enable by uncommenting the vpn.nix line
  # in flake.nix's desktopModules — nothing else needs editing here or in host
  # files. `lib.moduleSmoke` in flake.nix keeps this module evaluating while
  # it's out.
  #
  # Per-host bits are derived, not hand-set: the wg0 address is this host's
  # vpnIp from .claude/hosts.json (VPN subnet 10.10.0.0/24, vpn-server is
  # 10.10.0.1), and the private key comes from sops-nix's
  # secrets/hosts/<host>.yaml, decrypted at activation to
  # /run/secrets/wg-private-key.

  # The tunnel is full-tunnel but IPv4-only (no IPv6 address on wg0, and the
  # Oracle Cloud server does not route IPv6). IPv6 is disabled system-wide so
  # IPv6-only destinations fall back to IPv4 through the tunnel instead of being
  # black-holed (e.g. TMDb image fetches in Jellyfin hung the full 100s
  # HttpClient timeout). With IPv6 disabled there is no IPv6 stack to leak, so a
  # v4-only allowedIPs (0.0.0.0/0 below) still gives a full tunnel. NOTE: do NOT
  # add "::/0" to allowedIPs — wg-quick would try `ip -6 route add ::/0 dev wg0`,
  # which fails ("IPv6 is disabled on nexthop device") and tears the whole tunnel
  # down.
  networking.enableIPv6 = false;

  environment.systemPackages = [ pkgs.wireguard-tools ];

  sops.secrets."wg-private-key".sopsFile =
    ../secrets/hosts/${config.networking.hostName}.yaml;

  # Bring the tunnel up/down by hand (systemd unit name uses a hyphen, which is
  # how systemd renders the wg-quick@wg0 template; systemctl also avoids the
  # wg-quick binary not being on PATH for non-root shells).
  programs.zsh.shellAliases = {
    vpn-off = "sudo systemctl stop wg-quick-wg0";
    vpn-on = "sudo systemctl start wg-quick-wg0";
  };

  networking.wg-quick.interfaces.wg0 = {
    address = [ "${hostsData.hosts.${hostName}.vpnIp}/24" ];
    privateKeyFile = config.sops.secrets."wg-private-key".path;

    # natalie-laptop stays manual (vpn-on/vpn-off): the full-tunnel kill-switch
    # route (table 51820, suppress_prefixlength 0) captures all traffic —
    # including chrony's own NTP retries — the instant wg-quick starts, even
    # before the WireGuard handshake completes. If this laptop's WiFi is still
    # associating at that moment, every packet vanishes into the
    # not-yet-negotiated tunnel with no fallback, and nothing recovers until
    # the tunnel is torn down by hand. gaming/laptop haven't shown this, so
    # they keep the default autostart.
    autostart = hostName != "natalie-laptop";
    dns = [ "1.1.1.1" "8.8.8.8" ];

    # wg-quick defaults to MTU 1420, but the underlying path to the Oracle
    # endpoint can only carry ~1400-byte inner packets. With PMTU discovery
    # black-holed, full-size packets are silently dropped, which truncates large
    # downloads (e.g. nars from cache.nixos.org) while pings/small packets pass.
    # Clamp to 1380 to stay safely under the path MTU.
    mtu = 1380;

    peers = [
      {
        # vpn-server (Oracle Cloud ARM — 150.136.232.63)
        publicKey = "ijhN7KUmHx5TOLpKgyzJpzSvp49TkD0c2CTf32Cyu1U=";
        endpoint = "150.136.232.63:51820";

        # Full tunnel: route all IPv4 traffic through the VPN (v4-only — see note above)
        allowedIPs = [ "0.0.0.0/0" ];

        # Oracle Cloud silently drops idle UDP after ~30s; keep-alive prevents that
        persistentKeepalive = 25;
      }
    ];
  };
}
