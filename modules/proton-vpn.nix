{ pkgs, ... }:

{
  # Proton VPN GUI client for all desktop hosts. It drives NetworkManager;
  # first-time sign-in is manual per host inside the app (no declarative
  # credentials). It is a full-tunnel VPN, so it can interact with Tailscale
  # routes and with the pi-hole nameserver set in modules/desktop-networking.nix
  # (`networkmanager.dns = "none"`) — test both after connecting.
  environment.systemPackages = [ pkgs.proton-vpn ];
}
