{ config, pkgs, ... }:

{
  programs = {
    # Steam
    steam = {
      enable = true;
      remotePlay.openFirewall = true;
      dedicatedServer.openFirewall = true;
      localNetworkGameTransfers.openFirewall = true;

      # Global steam optional launch settings
      package = pkgs.steam.override {
        extraEnv = {
          ENABLE_VKBASALT = "1";
          GAMEMODERUN = "1";
          PROTON_ENABLE_WAYLAND = "1";
          PROTON_FSR4_UPGRADE = "1";
        };
      };
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
