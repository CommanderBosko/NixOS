{ config, pkgs, ... }:

{
  networking = {
    # Set host name
    hostName = "nixos-server";

    # Configure network proxy
    # networking.proxy.default = "http://user:password@proxy:port/";
    # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

    # Enable networking
    networkmanager.enable = true;

    # Some programs need SUID wrappers, can be configured further or are
    # started in user sessions.
    # programs.mtr.enable = true;
    # programs.gnupg.agent = {
    #   enable = true;
    #   enableSSHSupport = true;
    # };

    # SSH server
  services = {
    openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = false; # disable if using SSH keys
        PermitRootLogin = "no";
      };
    };

    # Clock sync
    ntp.enable = true;
  };

    # Enable and open ports in the firewall
    firewall = {
      enable = true;
      allowedTCPPorts = [ 22 ];
      # allowedUDPPorts = [ ... ];
    };
  };
}
