{
  description = "Bosko's NixOS Flake";

  inputs = {
    # Nix packages
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    # Stable nixpkgs — used by vpn-server for stability
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-25.11";

    # Dank Material Shell
    dms.url = "github:AvengeMedia/DankMaterialShell";

    # nix-colors — base16 palettes + Home Manager module, used by omarchy.nix
    # for Omarchy's real theme-driven styling (one palette feeds Hyprland,
    # Waybar, Hyprlock, mako). Only depends on a lib-only nixpkgs repackage
    # and the tinted-theming schemes data repo, not full nixpkgs — no
    # `follows` needed.
    nix-colors.url = "github:misterio77/nix-colors";

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
    # Modules shared by all systems. bootloader.nix is GRUB/x86 — vpn-server
    # overrides it with systemd-boot via mkForce in its configuration.nix.
    # system.stateVersion is per-host (frozen at each machine's install time).
    commonModules = [
      "${self}/modules/bootloader.nix"
      "${self}/modules/claude-code.nix"
      "${self}/modules/firmware.nix"
      "${self}/modules/fonts.nix"
      "${self}/modules/localisation.nix"
      "${self}/modules/nix.nix"
      "${self}/modules/security.nix"
      "${self}/modules/shell.nix"
      "${self}/modules/sops.nix"
      "${self}/modules/users.nix"
    ];

    desktopModules = commonModules ++ [
      home-manager.nixosModules.home-manager
      nix-flatpak.nixosModules.nix-flatpak
      "${self}/modules/audio.nix"
      "${self}/modules/desktop-apps.nix"
      "${self}/modules/desktop-networking.nix"
      "${self}/modules/emulation.nix"
      "${self}/modules/home-manager.nix"
      "${self}/modules/jellyfin-client.nix"
      "${self}/modules/printing.nix"
      "${self}/modules/sddm.nix"
      "${self}/modules/shared-folder.nix"
      # WireGuard client to vpn-server temporarily pulled from the fleet —
      # Oracle admin-disabled that instance 2026-08-18 (see
      # project_vpn_server_oracle_disabled memory), so the tunnel has no
      # working endpoint. Tailscale (modules/tailscale.nix, per-host) is the
      # mesh stopgap in the meantime. Re-add this line once vpn-server is
      # back; modules/vpn.nix itself is untouched.
      # "${self}/modules/vpn.nix"
    ];

    # Build a host. Sets networking.hostName from the attribute name and
    # injects the shared specialArgs, so each host entry holds only its
    # unique module list.
    mkSystem = { name, system ? "x86_64-linux", nixpkgs ? inputs.nixpkgs, modules }:
      nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs self system; };
        modules = [ { networking.hostName = name; } ] ++ modules;
      };

    # The laptop's module list, parameterised over the desktop-environment
    # module — reused by lib.deSmoke to evaluate every available DE.
    laptopModules = de: desktopModules ++ [
      # Machine-specific modules
      "${self}/hosts/laptop/hardware-configuration.nix"
      "${self}/hosts/laptop/environment.nix"
      "${self}/hosts/laptop/networking.nix"
      de
      "${self}/modules/nvidia.nix"
      "${self}/modules/shared-folder-client.nix"
      "${self}/modules/tailscale.nix"
    ];
  in
  {
    # Custom library functions
    lib.mkSystem = mkSystem;

    # Smoke-eval targets: the laptop config with each available DE module
    # swapped in. Unused DE modules are never evaluated by the host builds and
    # would otherwise rot silently across nixpkgs bumps; CI's de-smoke job
    # forces each one (eval-only, no builds).
    lib.deSmoke = nixpkgs.lib.genAttrs
      (map (f: nixpkgs.lib.removeSuffix ".nix" f)
        (builtins.attrNames (builtins.readDir ./modules/desktop-environments)))
      (de: mkSystem {
        name = "laptop";
        modules = laptopModules "${self}/modules/desktop-environments/${de}.nix";
      });

    # Configure nix configurations
    nixosConfigurations = {
      # Gaming
      gaming = mkSystem {
        name = "gaming";
        modules = desktopModules ++ [
          # Machine-specific modules
          "${self}/hosts/gaming/hardware-configuration.nix"
          "${self}/hosts/gaming/environment.nix"
          "${self}/hosts/gaming/networking.nix"
          "${self}/modules/desktop-environments/niri.nix"
          "${self}/modules/gaming.nix"
          "${self}/modules/nvidia.nix"
          "${self}/modules/tailscale.nix"
          "${self}/hosts/gaming/virtualisation.nix"
          "${self}/hosts/gaming/jellyfin-server.nix"
          "${self}/hosts/gaming/pinchflat.nix"
          "${self}/hosts/gaming/samba-shared.nix"
        ];
      };

      # Laptop
      laptop = mkSystem {
        name = "laptop";
        modules = laptopModules "${self}/modules/desktop-environments/niri.nix";
      };

      # Natalie's Laptop
      natalie-laptop = mkSystem {
        name = "natalie-laptop";
        modules = desktopModules ++ [
          # Machine-specific modules
          "${self}/hosts/natalie-laptop/hardware-configuration.nix"
          "${self}/hosts/natalie-laptop/environment.nix"
          "${self}/hosts/natalie-laptop/networking.nix"
          "${self}/hosts/natalie-laptop/virtualisation.nix"
          "${self}/modules/desktop-environments/niri.nix"
          "${self}/modules/nvidia.nix"
          "${self}/modules/shared-folder-client.nix"
          "${self}/modules/tailscale.nix"
        ];
      };

      # VPN Server (Oracle Cloud ARM) — pinned to nixos-25.11 for stability
      vpn-server = mkSystem {
        name = "vpn-server";
        system = "aarch64-linux";
        nixpkgs = nixpkgs-stable;
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
