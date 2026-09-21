{
  description = "Bosko's NixOS Flake";

  inputs = {
    # Nix packages
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    # Stable nixpkgs — used by vpn-server for stability
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-25.11";

    # TEMPORARY: pinned nixpkgs rev carrying xwayland-satellite 0.8.1 — the
    # last release before 0.8.2's popup-positioning regression broke Steam's
    # dropdown menus under niri (Supreeeme/xwayland-satellite#156). Consumed
    # only by the overlay in modules/desktop-environments/niri.nix, which
    # pulls just that one package — this does NOT hold back nixpkgs itself.
    # Remove this input + the overlay once upstream fixes the regression.
    nixpkgs-xwayland-satellite-pin.url = "github:nixos/nixpkgs/a5cbcfe954791221bfffe2307f7d1a1bf61a871e";

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
    # Host/network facts shared with the Claude tooling (.claude/hosts.json is
    # the single source of truth for IPs and WireGuard addresses); modules take
    # it as the `hostsData` argument instead of hardcoding addresses.
    hostsData = builtins.fromJSON (builtins.readFile ./.claude/hosts.json);

    # Modules shared by all systems, headless vpn-server included. Anything
    # that only makes sense on a desktop (bootloader/kernel, fonts, flatpak…)
    # lives in desktopModules so vpn-server doesn't have to override it.
    # system.stateVersion is per-host (frozen at each machine's install time).
    commonModules = [
      "${self}/modules/claude-code.nix"
      "${self}/modules/firmware.nix"
      "${self}/modules/localisation.nix"
      "${self}/modules/nix.nix"
      "${self}/modules/security.nix"
      "${self}/modules/shell.nix"
      "${self}/modules/sops.nix"
      "${self}/modules/ssh.nix"
      "${self}/modules/starship.nix"
      "${self}/modules/users.nix"
    ];

    desktopModules = commonModules ++ [
      home-manager.nixosModules.home-manager
      nix-flatpak.nixosModules.nix-flatpak
      "${self}/modules/audio.nix"
      # GRUB + zen kernel (x86 desktops); vpn-server owns its own boot config
      "${self}/modules/bootloader.nix"
      "${self}/modules/desktop-apps.nix"
      "${self}/modules/desktop-networking.nix"
      "${self}/modules/development.nix"
      "${self}/modules/emulation.nix"
      "${self}/modules/flatpak.nix"
      "${self}/modules/fonts.nix"
      "${self}/modules/home-manager.nix"
      "${self}/modules/jellyfin-client.nix"
      "${self}/modules/printing.nix"
      "${self}/modules/sddm.nix"
      # Mesh VPN on every desktop; first-time auth is manual (`tailscale up`)
      "${self}/modules/tailscale.nix"
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
        specialArgs = { inherit hostsData inputs self system; };
        modules = [ { networking.hostName = name; } ] ++ modules;
      };

    # The laptop's module list, parameterised over the desktop-environment
    # module — reused by lib.deSmoke to evaluate every available DE.
    laptopModules = de: desktopModules ++ [
      # Machine-specific modules
      "${self}/hosts/laptop/hardware-configuration.nix"
      "${self}/hosts/laptop/environment.nix"
      de
      "${self}/modules/nvidia.nix"
      "${self}/modules/qbittorrent.nix"
      "${self}/modules/shared-folder-client.nix"
    ];

    # The gaming host's module list, parameterised over the GPU module and
    # any extra modules — reused by lib.moduleSmoke.
    gamingModules = { gpu ? "${self}/modules/nvidia.nix", extra ? [ ] }: desktopModules ++ [
      # Machine-specific modules
      "${self}/hosts/gaming/hardware-configuration.nix"
      "${self}/hosts/gaming/environment.nix"
      "${self}/hosts/gaming/networking.nix"
      "${self}/modules/desktop-environments/niri.nix"
      "${self}/modules/gaming.nix"
      gpu
      "${self}/hosts/gaming/virtualisation.nix"
      "${self}/hosts/gaming/jellyfin-server.nix"
      "${self}/hosts/gaming/pinchflat.nix"
      "${self}/hosts/gaming/samba-shared.nix"
    ] ++ extra;
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

    # Smoke-eval targets for modules no host imports right now: amd.nix (staged
    # for the gaming GPU swap) and vpn.nix (WireGuard client, out while
    # vpn-server is down). Same idea as deSmoke — they'd otherwise rot silently
    # across nixpkgs bumps; CI forces each one (eval-only, no builds).
    lib.moduleSmoke = {
      amd = mkSystem {
        name = "gaming";
        modules = gamingModules { gpu = "${self}/modules/amd.nix"; };
      };
      vpn = mkSystem {
        name = "gaming";
        modules = gamingModules { extra = [ "${self}/modules/vpn.nix" ]; };
      };
    };

    # Configure nix configurations
    nixosConfigurations = {
      # Gaming
      gaming = mkSystem {
        name = "gaming";
        modules = gamingModules { };
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
          "${self}/modules/desktop-environments/niri.nix"
          "${self}/modules/nvidia.nix"
          "${self}/modules/qbittorrent.nix"
          "${self}/modules/shared-folder-client.nix"
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
