{
  description = "Bosko's NixOS Flake";

  inputs = {
    # Nix packages
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    # Stable nixpkgs — used by server and vpn-server for stability
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-25.05";

    # Dank Material Shell
    dms.url = "github:AvengeMedia/DankMaterialShell";

    # Home manager
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Nix-Flatpaks
    nix-flatpak.url = "github:gmodena/nix-flatpak/?ref=latest";

    # Disko — declarative disk partitioning (used by vpn-server / nixos-anywhere)
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # FinanceGuru — personal finance desktop app
    financeguru.url = "github:CommanderBosko/FinanceGuru";

    # sops-nix — encrypted secrets committed in-repo (login password hashes,
    # WireGuard private keys). Lets the repo be public without leaking secrets.
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

  };

  outputs = { disko, home-manager, nix-flatpak, nixpkgs, nixpkgs-stable, self, ... }@inputs:
  let
    # Configure system settings
    system = "x86_64-linux";

    # Modules shared by all systems (no bootloader — each host provides its own)
    commonModules = [
      { system.stateVersion = "25.11"; }
      "${self}/dotfiles/common/modules/bootloader.nix"
      "${self}/dotfiles/common/modules/claude-code.nix"
      "${self}/dotfiles/common/modules/firmware.nix"
      "${self}/dotfiles/common/modules/fonts.nix"
      "${self}/dotfiles/common/modules/localisation.nix"
      "${self}/dotfiles/common/modules/nix.nix"
      "${self}/dotfiles/common/modules/security.nix"
      "${self}/dotfiles/common/modules/shell.nix"
      "${self}/dotfiles/common/modules/sops.nix"
      "${self}/dotfiles/common/modules/users.nix"
    ];

    desktopModules = commonModules ++ [
      home-manager.nixosModules.home-manager
      nix-flatpak.nixosModules.nix-flatpak
      "${self}/dotfiles/common/modules/audio.nix"
      "${self}/dotfiles/common/modules/emulation.nix"
      "${self}/dotfiles/common/modules/home-manager.nix"
      "${self}/dotfiles/common/modules/printing.nix"
      "${self}/dotfiles/common/modules/sddm.nix"
    ];
  in
  {
    # Custom library functions
    lib.mkSystem = { modules, nixpkgs, specialArgs, ... }:
      nixpkgs.lib.nixosSystem {
        inherit specialArgs;
        system = specialArgs.system;
        modules = modules;
      };

    # Configure nix configurations
    nixosConfigurations = {
      # Gaming
      gaming = self.lib.mkSystem {
        inherit inputs system nixpkgs;
        specialArgs = { inherit inputs self system; };
        modules = desktopModules ++ [
          # Machine-specific modules
          "${self}/hosts/gaming/hardware-configuration.nix"
          "${self}/hosts/gaming/environment.nix"
          "${self}/hosts/gaming/networking.nix"
          "${self}/dotfiles/common/modules/desktop-environments/plasma.nix"
          "${self}/dotfiles/common/modules/gaming.nix"
          "${self}/dotfiles/common/modules/nvidia.nix"
          "${self}/hosts/gaming/virtualisation.nix"
          "${self}/hosts/gaming/brobot.nix"
          "${self}/dotfiles/common/modules/vpn.nix"
        ];
      };

      # Laptop
      laptop = self.lib.mkSystem {
        inherit inputs system nixpkgs;
        specialArgs = { inherit inputs self system; };
        modules = desktopModules ++ [
          # Machine-specific modules
          "${self}/hosts/laptop/hardware-configuration.nix"
          "${self}/hosts/laptop/environment.nix"
          "${self}/hosts/laptop/networking.nix"
          "${self}/dotfiles/common/modules/desktop-environments/niri.nix"
          "${self}/dotfiles/common/modules/nvidia.nix"
          "${self}/dotfiles/common/modules/vpn.nix"
        ];
      };

      # Natalie's Laptop
      natalie-laptop = self.lib.mkSystem {
        inherit inputs system nixpkgs;
        specialArgs = { inherit inputs self system; };
        modules = desktopModules ++ [
          # Machine-specific modules
          "${self}/hosts/natalie-laptop/hardware-configuration.nix"
          "${self}/hosts/natalie-laptop/environment.nix"
          "${self}/hosts/natalie-laptop/networking.nix"
          "${self}/dotfiles/common/modules/desktop-environments/plasma.nix"
          "${self}/dotfiles/common/modules/nvidia.nix"
          "${self}/dotfiles/common/modules/vpn.nix"
        ];
      };

      # VPN Server (Oracle Cloud ARM) — pinned to nixos-25.05 for stability
      vpn-server = self.lib.mkSystem {
        inherit inputs;
        nixpkgs = nixpkgs-stable;
        specialArgs = {
          inherit inputs self;
          system = "aarch64-linux";
        };
        modules = commonModules ++ [
          disko.nixosModules.disko
          "${self}/hosts/vpn-server/hardware-configuration.nix"
          "${self}/hosts/vpn-server/disko.nix"
          "${self}/hosts/vpn-server/configuration.nix"
        ];
      };
    };
  };
}
