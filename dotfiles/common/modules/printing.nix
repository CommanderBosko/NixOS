{ pkgs, ... }:

{
  services.printing = {
    enable = true;
    drivers = with pkgs; [ gutenprint hplip brlaser ];
  };

  environment.systemPackages = with pkgs; [
    kdePackages.print-manager
  ];

  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };
}
