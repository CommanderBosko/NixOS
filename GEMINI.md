# Gemini CLI Project Context: NixOS Configuration

## Project Overview

This project is a NixOS Flake designed to manage system and user configurations across various machines: `gaming`, `laptop`, and `server`. It leverages Nix Flakes for declarative system configuration, Home Manager for user-specific dotfiles and packages, and integrates `nix-flatpak` for Flatpak management on the `gaming` and `laptop` systems. The configurations are modularized within the `dotfiles` directory, separating common modules from machine-specific environments and networking settings.

## Building and Running

To activate the configurations for a specific host, navigate to the project root and use the `nixos-rebuild` command with the `--flake` option, specifying the desired host.

**Example: Building and activating the configuration for the 'gaming' host:**

```bash
sudo nixos-rebuild switch --flake .#gaming
```

Replace `gaming` with `laptop` or `server` for other machines.

**Home Manager specific activation:**

After a system rebuild, Home Manager configurations for users `bosko` and `natty` are applied. If you make changes specifically to Home Manager configurations (e.g., in `dotfiles/common/configs/home.nix`), you might need to rebuild the system or switch to the Home Manager generation.

## Development Conventions

*   **Nix Flakes:** The project uses Nix Flakes as its primary method for managing dependencies and system configurations.
*   **Modular Configuration:** Configurations are organized modularly within the `dotfiles` directory, with `common/modules` for shared system settings, `common/configs` for shared user dotfiles, and machine-specific directories (e.g., `gaming/`, `laptop/`, `server/`) for environment and networking settings unique to each host.
*   **Home Manager:** User-specific configurations (dotfiles, packages, services) are managed declaratively using Home Manager.
*   **`nix-flatpak` Integration:** Flatpak applications are managed through `nix-flatpak` on the `gaming` and `laptop` systems.
*   **Unfree Packages:** The configuration explicitly allows unfree packages (`nixpkgs.config.allowUnfree = true`) to enable a wider range of software.

## Key Files Analyzed

*   `flake.nix`: The main entry point for the Nix Flake, defining inputs (nixpkgs, home-manager, nix-flatpak) and outputs (nixosConfigurations for gaming, laptop, server).
*   `dotfiles/common/modules/nix.nix`: Contains global Nix settings, including experimental features, store optimization, and download buffer size.
*   `dotfiles/common/modules/home-manager.nix`: Configures Home Manager as a NixOS module, enabling it for users `bosko` and `natty` and pointing to their respective home configurations.
*   `dotfiles/common/configs/home.nix`: Defines user-specific Home Manager configurations, including packages and the management of dotfiles like `katerc`, `kitty.conf`, and `starship.toml`.
