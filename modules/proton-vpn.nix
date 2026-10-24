{ pkgs, ... }:

let
  waitForTray = pkgs.writeShellScript "protonvpn-app-wait-tray" ''
    # Gives up after ~30 s and launches anyway (window shows, as before).
    for _ in $(${pkgs.coreutils}/bin/seq 150); do
      ${pkgs.systemd}/bin/busctl --user status org.kde.StatusNotifierWatcher >/dev/null 2>&1 && break
      ${pkgs.coreutils}/bin/sleep 0.2
    done
    exec ${pkgs.proton-vpn}/bin/protonvpn-app --start-minimized
  '';
in
{
  # Proton VPN GUI client for all desktop hosts. It drives NetworkManager;
  # first-time sign-in is manual per host inside the app (no declarative
  # credentials). It is a full-tunnel VPN, so it can interact with Tailscale
  # routes and with the pi-hole nameserver set in modules/desktop-networking.nix
  # (`networkmanager.dns = "none"`) — test both after connecting.
  environment.systemPackages = [ pkgs.proton-vpn ];

  # Autostart at login, minimized to the tray, for every user on the host.
  # The app checks for org.kde.StatusNotifierWatcher once at startup and shows
  # its window if the tray isn't there yet; DMS registers it ~2 s after login,
  # so the wrapper waits for it first. Connecting to the fastest server on
  # launch is a per-user setting inside the app (Settings > General >
  # "Auto connect" = `Fastest`); Nix can't set it.
  environment.etc."xdg/autostart/protonvpn-app.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=Proton VPN
    Exec=${waitForTray}
    Icon=proton-vpn-logo
    Terminal=false
  '';
}
