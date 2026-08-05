{ ... }:

{
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;

    settings = {
      "*" = {
        ServerAliveInterval = 60;
        ServerAliveCountMax = 3;
      };

      "natalie-laptop" = {
        Hostname = "10.0.0.101";
        User = "bosko";
      };

      "laptop" = {
        Hostname = "10.0.0.227";
        User = "bosko";
      };

      "gaming" = {
        Hostname = "10.0.0.251";
        User = "bosko";
      };

      "pi-hole" = {
        Hostname = "10.0.0.19";
        User = "bosko";
      };

      "famdash" = {
        Hostname = "10.0.0.20";
        User = "natty";
      };
    };
  };
}
