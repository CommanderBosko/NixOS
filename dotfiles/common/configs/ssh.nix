{ ... }:

{
  programs.ssh = {
    enable = true;
    matchBlocks = {
      "natalie-laptop" = {
        hostname = "10.0.0.103";
        user = "bosko";
      };
      "laptop" = {
        hostname = "10.0.0.227";
        user = "bosko";
      };
      "gaming" = {
        hostname = "10.0.0.251";
        user = "bosko";
      };
      "pi-hole" = {
        hostname = "10.0.0.20";
        user = "bosko";
      };
      "famdash" = {
        hostname = "10.0.0.21";
        user = "natalie";
      };
    };
  };
}
