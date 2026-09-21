{ ... }:

{
  # SSH server hardening shared by every host, headless vpn-server included:
  # key-only login, no root. Port 22 is opened by services.openssh.openFirewall
  # (default true). Per-host extras stay in host files — e.g.
  # desktop-networking.nix pins AllowUsers.
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
      PrintMotd = false;
    };
  };
}
