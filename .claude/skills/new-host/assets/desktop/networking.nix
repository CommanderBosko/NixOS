{ ... }:

{
  # Configure networking
  networking = {
    # Set host name
    hostName = "<hostname>";

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
