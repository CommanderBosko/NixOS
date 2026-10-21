{ pkgs, ... }:

{
  # Proton VPN GUI client (protonvpn-app) and CLI (protonvpn) for all desktop
  # hosts. Both can be installed together, but Proton doesn't support running
  # them at the same time — use one per connection. They drive NetworkManager;
  # first-time sign-in is manual per host inside the app (no declarative
  # credentials). It is a full-tunnel VPN, so it can interact with Tailscale
  # routes and with the pi-hole nameserver set in modules/desktop-networking.nix
  # (`networkmanager.dns = "none"`) — test both after connecting.
  environment.systemPackages = [
    pkgs.proton-vpn
    pkgs.proton-vpn-cli
  ];
}
