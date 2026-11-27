{
  description = "Bosko's NixOS Flake";

  inputs = {
    # Nix packages
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    # TEMPORARY (re-added 2026-11-15, originally 2026-11-14): nixpkgs rev fe132422
    # (2026-10-15), the last one whose linux-zen (7.2.10) boots on natalie-laptop
    # with working Wi-Fi: on zen 7.3.4-zen2 and stable 6.18.63 its Intel AX201
    # firmware asserts at first load (iwlwifi "Microcode SW error"). (It was first
    # added because 7.3.4 panicked on gaming; that was fixed in 7.3.4-zen2.)
    # Consumed only by hosts/natalie-laptop/environment.nix for
    # boot.kernelPackages (kernel + its nvidia module set); it does NOT hold back
    # nixpkgs itself. Lift: delete kernelPkgs, the overlay and the kernelPackages
    # line there, then drop this input and flake.lock entry.
    nixpkgs-kernel.url = "github:nixos/nixpkgs/fe13242281a67641c0102cdb1087f0ebe586c7df";

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

    # FinanceGuru — personal finance desktop app
    financeguru.url = "github:CommanderBosko/FinanceGuru";

    # sops-nix — encrypted secrets committed in-repo (login password hashes,
    # API tokens, service secrets). Lets the repo be public without leaking secrets.
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # FamDash — the family dashboard app run by the famdash Raspberry Pi
    # (hosts/famdash/famdash.nix). PRIVATE repo, fetched over SSH. flake = false
    # makes it lazy: only the famdash host references it, so gaming and the
    # laptops never fetch it, but the lock entry must stay committed, a full
    # `nix flake update` needs SSH access to the repo (gaming has it), and CI
    # loads a read-only deploy key (see .github/workflows/check.yml).
    famdash = {
      url = "git+ssh://git@github.com/CommanderBosko/FamDash";
      flake = false;
    };

    # Hermes Agent — AI agent framework by Nous Research (every desktop host).
    # No `follows`: upstream pins its own nixpkgs.
    hermes-agent.url = "github:NousResearch/hermes-agent";

    # Hermes copies of the Claude Code plugins (modules/hermes-agent.nix).
    # Track the default branch so `nix flake update` bumps them.
    superpowers = {
      url = "github:obra/superpowers";
      flake = false;
    };
    ponytail = {
      url = "github:DietrichGebert/ponytail";
      flake = false;
    };
    # Hermes memory provider (modules/hermes-mnemosyne.nix).
    mnemosyne = {
      url = "github:mnemosyne-oss/mnemosyne";
      flake = false;
    };
  };

  outputs = { home-manager, nix-flatpak, nixpkgs, self, ... }@inputs:
  let
    # Host/network facts shared with the Claude tooling (.claude/hosts.json is
    # the single source of truth for IPs and Tailscale addresses); modules take
    # it as the `hostsData` argument instead of hardcoding addresses.
    hostsData = builtins.fromJSON (builtins.readFile ./.claude/hosts.json);

    # Modules shared by all systems, including any future headless host.
    # Anything that only makes sense on a desktop (bootloader/kernel, fonts,
    # flatpak…) lives in desktopModules so a headless host doesn't have to
    # override it.
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
      # GRUB + zen kernel (x86 desktops); a headless host would own its own boot config
      "${self}/modules/bootloader.nix"
      "${self}/modules/claude-mcp.nix"
      "${self}/modules/desktop-apps.nix"
      "${self}/modules/desktop-networking.nix"
      "${self}/modules/development.nix"
      "${self}/modules/emulation.nix"
      "${self}/modules/flatpak.nix"
      "${self}/modules/fonts.nix"
      "${self}/modules/herdr.nix"
      # Hermes Agent CLI on OpenRouter (HM, bosko); key in secrets/desktop.yaml
      "${self}/modules/hermes-agent.nix"
      "${self}/modules/home-manager.nix"
      "${self}/modules/jellyfin-client.nix"
      # Host metrics for gaming's Prometheus; tailscale0 only
      "${self}/modules/node-exporter.nix"
      "${self}/modules/printing.nix"
      "${self}/modules/sddm.nix"
      # Mesh VPN on every desktop; first-time auth is manual (`tailscale up`)
      "${self}/modules/tailscale.nix"
      # Proton VPN GUI client; sign-in is manual per host (see the module)
      "${self}/modules/proton-vpn.nix"
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
      "${self}/hosts/gaming/immich.nix"
      "${self}/hosts/gaming/monitoring.nix"
      "${self}/hosts/gaming/pinchflat.nix"
      "${self}/hosts/gaming/samba-shared.nix"
      "${self}/hosts/gaming/github-runner.nix"
      "${self}/hosts/gaming/hermes-agent.nix"
      "${self}/hosts/gaming/proton-mail.nix"
      "${self}/hosts/gaming/vesktop-direct.nix"
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
    # for the gaming GPU swap). Same idea as deSmoke — it would otherwise rot
    # silently across nixpkgs bumps; CI forces each one (eval-only, no builds).
    lib.moduleSmoke = {
      amd = mkSystem {
        name = "gaming";
        modules = gamingModules { gpu = "${self}/modules/amd.nix"; };
      };
    };

    # Runtime test of the pi-hole host's DNS stack (FTL + unbound + declarative
    # clients) in an x86_64 VM with fixture data. A package, not a flake check:
    # CI only evaluates it; boot it on gaming with
    #   nix build .#packages.x86_64-linux.pihole-vm-test -L
    packages.x86_64-linux.pihole-vm-test = import ./hosts/pi-hole/vm-test.nix {
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
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
          "${self}/hosts/natalie-laptop/virtualisation.nix"
          "${self}/modules/desktop-environments/niri.nix"
          "${self}/modules/nvidia.nix"
          "${self}/modules/qbittorrent.nix"
          "${self}/modules/shared-folder-client.nix"
        ];
      };

      # famdash — family dashboard Raspberry Pi 4B: headless, Wi-Fi only, booted
      # from an SD image built on gaming (see hosts/famdash/configuration.nix)
      famdash = mkSystem {
        name = "famdash";
        system = "aarch64-linux";
        modules = commonModules ++ [
          "${self}/hosts/famdash/configuration.nix"
        ];
      };

      # pi-hole — the household DNS appliance Raspberry Pi 4B: Pi-hole v6 + local
      # unbound, wired, booted from an SD image built on gaming (see
      # hosts/pi-hole/configuration.nix)
      pi-hole = mkSystem {
        name = "pi-hole";
        system = "aarch64-linux";
        modules = commonModules ++ [
          "${self}/hosts/pi-hole/configuration.nix"
        ];
      };
    };
  };
}
