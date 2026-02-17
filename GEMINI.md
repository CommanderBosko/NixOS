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

## Recent Modifications (as of February 16, 2026)

This section summarizes recent changes made to the NixOS configuration.

### Desktop Environment Modules

New modules for various desktop environments have been introduced under `dotfiles/common/modules/desktop-environments/`. For each, a module was created, temporarily integrated into the `laptop` configuration for dry-run testing, and then its integration removed (the module file itself was kept unless noted otherwise).

*   **`hyprland.nix`**: Configures the Hyprland compositor. Includes basic enablement and common Wayland companion packages. A previous change had uncommented GDM configuration within this file.
*   **`niri.nix`**: Configures the Niri compositor. Includes basic enablement and common Wayland companion packages.
*   **`plasma.nix`**: Configures the KDE Plasma desktop environment. Initially had a syntax error in `environment.systemPackages` (incorrect `kdePackages = { ... };` syntax), which was corrected.
*   **`cosmic.nix`**: Configures the Cosmic desktop environment. Initially had an "undefined variable 'cosmic-epoch'" error for a package, which was resolved by removing the `environment.systemPackages` entry entirely, as Cosmic DE is primarily enabled via services.
*   **`gnome.nix`**: Configures the GNOME desktop environment. Initially caused a conflict with SDDM (`services.displayManager.defaultSession`) and had incorrect package references (`gnome.gnome-terminal` instead of `pkgs.gnome-terminal`). Both were fixed by temporarily commenting out `defaultSession` in `laptop/environment.nix` and correcting package paths.
*   **`xfce.nix`**: Configures the XFCE desktop environment. Initially had an "option does not exist" error for `services.desktopManager.xfce`, which was fixed by correcting the path to `services.xserver.desktopManager.xfce`. Also had evaluation warnings for `xfce.<package>` references, suggesting direct `pkgs.<package>` usage.
*   **`wayfire.nix`**: Configures the Wayfire Wayland compositor. Initially had an "attribute 'environment.systemPackages' already defined" error due to duplicate `environment.systemPackages` blocks, which was fixed by combining them into one.
*   **`cinnamon.nix`**: Configures the Cinnamon desktop environment. Initially caused a conflict with `defaultSession` (defined in `laptop/environment.nix`) and had incorrect package references (`cinnamon.nemo` instead of `pkgs.nemo`). Both were fixed by temporarily commenting out `defaultSession` in `laptop/environment.nix` and correcting package paths.
*   **`mate.nix`**: Configures the MATE desktop environment. Initially had "attribute 'mate-session' missing" and other package resolution errors (`mate.applets` instead of `mate.mate-panel-with-applets`), which were fixed by correcting the package references to use the appropriate `mate.<package>` or `pkgs.<package>` paths.
*   **`deepin.nix`**: A module for the Deepin Desktop Environment was created. However, dry-run testing revealed that Deepin DE has been **removed from Nixpkgs due to lack of maintenance**. The module was integrated and tested, but due to its non-functional status, its integration was removed from the laptop configuration, and the `deepin.nix` file itself was subsequently deleted.

### Display Manager Standardization

All desktop environment modules under `dotfiles/common/modules/desktop-environments/` have been standardized to use SDDM (Simple Desktop Display Manager) with the `breeze` theme. For Wayland-native desktop environments or compositors, their respective Wayland sessions are set as the default. For X11-native environments, their X11 sessions are used. `sddm` has been added to `environment.systemPackages` for all relevant modules, and conflicting display manager configurations (e.g., LightDM, GDM) have been removed. This change aims to provide a unified and consistent login experience across all desktop environments.

### Process for Adding New Desktop Environments

To add a new desktop environment module:
1.  Create a new `.nix` file (e.g., `my-de.nix`) in `dotfiles/common/modules/desktop-environments/`.
2.  Add the necessary NixOS configuration to enable the desktop environment and include relevant companion packages in `environment.systemPackages`.
3.  Add the new file to Git (`git add dotfiles/common/modules/desktop-environments/my-de.nix`).
4.  To enable it for a specific machine (e.g., `laptop`), add an `imports` statement to that machine's `flake.nix` for temporary testing, or permanently in `environment.nix`:
    ```nix
    # Example for flake.nix (temporary testing):
    modules = desktopModules ++ [
      # Machine-specific modules
      "${self}/dotfiles/laptop/hardware-configuration.nix"
      "${self}/dotfiles/laptop/environment.nix"
      "${self}/dotfiles/laptop/networking.nix"
      "${self}/dotfiles/common/modules/desktop-environments/my-de.nix" # Temporary
    ];

    # Example for environment.nix (permanent integration):
    imports = [
      ../../dotfiles/common/modules/desktop-environments/my-de.nix
    ];
    ```
5.  Perform a `nixos-rebuild dry-run --flake .#<machine-name>` to verify the configuration, debugging any errors.
6.  If necessary, temporarily comment out conflicting display manager settings (e.g., `services.displayManager.defaultSession`) in the machine's `environment.nix` during testing.
7.  Once verified, remove the temporary integration from `flake.nix` (or uncomment `defaultSession` in `environment.nix`), and then commit the changes.
8.  The desktop environment module file (`my-de.nix`) is typically kept after testing for future reference.