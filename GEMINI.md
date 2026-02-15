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

## Detailed Architecture Overview

The NixOS configuration is well-structured using the flake paradigm. The `flake.nix` serves as the central orchestrator, defining three distinct machine types: `gaming`, `laptop`, and `server`. It combines shared modules from `dotfiles/common/modules` with specialized configurations from machine-specific directories.

Key architectural points:
- **Modular Inheritance:** The `desktopModules` list is a good example of composition, where `gaming` and `laptop` systems inherit a base set of common desktop-oriented modules.
- **System Specialization:** The primary differences between machines are defined in their respective `environment.nix` and `networking.nix` files. The `gaming` machine is configured for running games (using `nix-ld`), the `laptop` is a general-purpose desktop with touchpad support, and the `server` is a headless machine focused on stability and automation.
- **Home Manager:** Home Manager is used in a standalone mode, defined in `flake.nix` under `homeConfigurations`. This means user-level configuration is decoupled from the main system build and must be applied manually with `home-manager switch`. Both users share the same configuration from `dotfiles/common/configs/home.nix`, which links dotfiles into their home directories.
- **Input Management:** Flake inputs like `home-manager` and `nix-flatpak` are defined once in `flake.nix` and passed down to modules via `specialArgs`, ensuring consistency. `nix-flatpak` is integrated by including its NixOS module in the `desktopModules`.
- **Minor Redundancy:** There's a harmless redundancy in `flake.nix` where `nix.nix`, `users.nix`, and `shell.nix` are included in both `commonModules` and the custom `lib.mkSystem` function. Nix's declarative nature merges these gracefully.