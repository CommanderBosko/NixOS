{ pkgs, inputs, ... }:

{
  # Frozen at this machine's install-time NixOS release — never bump on upgrades
  system.stateVersion = "25.11";

  # Services
  services = {
    # Display manager settings
    displayManager = {
      autoLogin.enable = false;
    };
  };

  # Hardware
  hardware = {
    # Bluetooth settings
    bluetooth = {
      enable = false;
      powerOnBoot = false;
      settings.General = {
        Enable = "Source,Sink,Media,Socket";
        Experimental = true;
      };
    };

    # Enable graphical interface
    graphics.enable = true;
  };

  # Enable aarch64 emulation so this machine can build for vpn-server (Oracle ARM)
  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];
  nix.settings.extra-platforms = [ "aarch64-linux" ];

  # Programs
  programs = {
    # Shell aliases
    zsh.shellAliases = {
      rift = "~/Rift/bin/rift";
    };
  };

  # Host-specific packages, on top of the shared modules/desktop-apps.nix list
  environment.systemPackages = with pkgs; [
    inputs.financeguru.packages.${pkgs.stdenv.hostPlatform.system}.default
    element-desktop
    mumble
    obs-studio
    qbittorrent
    tmux
    tor-browser
  ];

  # Host-specific flatpaks, on top of the shared modules/desktop-apps.nix list
  services.flatpak.packages = [
    "com.albiononline.AlbionOnline" # Albion Online
  ];
}
