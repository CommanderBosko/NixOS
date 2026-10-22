{ pkgs, ... }:

{
  # Proton VPN GUI client for all desktop hosts. It drives NetworkManager;
  # first-time sign-in is manual per host inside the app (no declarative
  # credentials). It is a full-tunnel VPN, so it can interact with Tailscale
  # routes and with the pi-hole nameserver set in modules/desktop-networking.nix
  # (`networkmanager.dns = "none"`) — test both after connecting.
  environment.systemPackages = [ pkgs.proton-vpn ];

  # Autostart at login, minimized to the tray, for every user on the host.
  # Connecting to the fastest server on launch is a per-user setting inside
  # the app (Settings > General > "Auto connect" = `Fastest`); Nix can't set it.
  environment.etc."xdg/autostart/protonvpn-app.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=Proton VPN
    Exec=${pkgs.proton-vpn}/bin/protonvpn-app --start-minimized
    Icon=proton-vpn-logo
    Terminal=false
  '';
}
