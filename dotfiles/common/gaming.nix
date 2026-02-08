{ config, pkgs, ... }:

{
  programs = {
    steam = {
        enable = true;
        remotePlay.openFirewall = true;
        dedicatedServer.openFirewall = true;
        localNetworkGameTransfers.openFirewall = true;
    };

    gamemode.enable = true;
  };

  environment.systemPackages = with pkgs; [
    faugus-launcher
    gamemode
    heroic
    lutris
    mangohud
    mangojuice
    protontricks
    protonup-qt
    r2modman
    vkbasalt
    vulkan-tools
  ];
}
