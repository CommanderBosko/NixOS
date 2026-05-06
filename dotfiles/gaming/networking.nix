{ ... }:

{
  # Configure networking
  networking = {
    # Set host name
    hostName = "gaming";

    # Configure network proxy
    # proxy.default = "http://user:password@proxy:port/";
    # proxy.noProxy = "127.0.0.1,localhost,internal.domain";

    # Enable networking
    networkmanager = {
      enable = true;
      dns = "none";
    };

    # Enable custom DNS servers
    nameservers = [
      "10.0.0.20"
      "1.1.1.1"
    ];

    # Enable and open ports in the firewall
    firewall = {
      enable = true;
      allowedTCPPorts = [ 22 ];
    };
  };

  # SSH settings
  services = {
    # Network clock sync
    chrony.enable = true;

    # Enable and configure openssh
    openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = false;
        PermitRootLogin = "no";
        PrintMotd = false;
        AllowUsers = [ "bosko" ];
      };
    };
  };
}
