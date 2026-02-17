{ config, pkgs, ... }:

{
  services.displayManager = {
    sddm = {
      enable = true;
      theme = "breeze";
    };
  };

  environment.systemPackages = with pkgs; [
    sddm # The SDDM display manager
  ];
}