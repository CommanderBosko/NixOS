{ config, pkgs, ... }:

{
  programs = {
    # Steam
    steam = {
        enable = true;
        remotePlay.openFirewall = true;
        dedicatedServer.openFirewall = true;
        localNetworkGameTransfers.openFirewall = true;
    };

    # Gamemode
    gamemode.enable = true;
  };

  # Gaming packages
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
