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

## Recent Modifications (as of April 21, 2026)

### Security Module Cleanup

*   **Security Module Removal**:
    *   **`dotfiles/common/modules/security.nix`**: Deleted the module which previously configured Apparmor and its utilities.
*   **Flake Configuration Update**:
    *   **`flake.nix`**: Removed the import of `security.nix` from the `commonModules` list to ensure the system configuration remains clean and evaluates correctly.

## Recent Modifications (as of April 19, 2026)

### Removal of Containerization Stack (Kubernetes, Podman, Docker)

*   **Virtualisation Module Refactoring**:
    *   **`dotfiles/common/modules/virtualisation.nix`**: Completely removed Kubernetes (master/node roles, CoreDNS, certificates) and Podman (registries, docker compatibility) configurations. The module is now focused exclusively on KVM/libvirt.
*   **User and Group Management**:
    *   **`dotfiles/common/modules/users.nix`**: Removed the `podman` group from the `extraGroups` list for users `bosko` and `natty`.
*   **System Packages and Shell Cleanup**:
    *   **`dotfiles/common/modules/shell.nix`**: Removed `docker` and `distrobox` from the global system packages.
*   **Application and Configuration Cleanup**:
    *   **`dotfiles/common/configs/starship.toml`**: Restored the `docker_context` to the prompt configuration.
    *   **`dotfiles/common/configs/helix.nix`**: Removed `dockerfile-language-server` and the associated language configuration for Dockerfiles.

## Recent Modifications (as of April 18, 2026)

### Shell and Kernel Enhancements

*   **Shell Aliases**:
    *   **`dotfiles/common/modules/shell.nix`**: Enhanced `rebuild` and `dry-run` aliases to dynamically use the current host name (`${hostName}`), improving portability across different machines.
*   **Kernel Testing**:
    *   Performed testing of kernel parameters on the `gaming` host.

## Recent Modifications (as of April 17, 2026)

### Application and CLI Tooling

*   **Claude Code Integration**:
    *   **`dotfiles/gaming/environment.nix`**, **`dotfiles/laptop/environment.nix`**: Added `claude-code` to the system packages.
*   **Rift Launcher**:
    *   **`dotfiles/gaming/environment.nix`**: Added a shell alias for the `rift` launcher.

## Recent Modifications (as of April 12, 2026)

### Architectural Refinement and Host Configuration

*   **Module Decoupling**: Moved `dotfiles/common/modules/gaming.nix` from the shared `desktopModules` list to the `gaming` host's specific module list in `flake.nix`. This ensures gaming-related packages (Steam, MangoHud, etc.) are only installed on the gaming machine, keeping the `laptop` configuration leaner.
*   **Laptop Environment Transition**: Switched the `laptop` host from the Cosmic desktop environment to the Niri compositor by updating the module imports in `flake.nix`.
*   **Code Quality**: Performed a full reformatting of `flake.nix` for better readability and structural consistency.

### Niri, SDDM, and Application Enhancements

*   **Niri Configuration Enhancement**: Enabled `xwayland` and `xserver` (X11) within `dotfiles/common/modules/desktop-environments/niri.nix` to improve application compatibility for Niri.
*   **SDDM and GTK Support**:
    *   **`dotfiles/common/modules/sddm.nix`**: Enabled `dconf` to support GTK settings and standardized the `xdg.portal` configuration.
*   **Application Management (Laptop)**:
    *   **`dotfiles/laptop/environment.nix`**: Migrated Deezer from a system package (`deezer-enhanced`) to a managed Flatpak application (`dev.aunetx.deezer`) on the laptop.
*   **Flake Maintenance**:
    *   Updated `flake.lock` to reflect latest upstream changes.

## Recent Modifications (as of April 11, 2026)

### Dank Material Shell (DMS) Integration

*   **Flake Inputs**:
    *   **`flake.nix`**: Added the Dank Material Shell (`dms`) flake input from `github:AvengeMedia/DankMaterialShell`.
*   **Home Manager Refactoring**:
    *   **`dotfiles/common/modules/home-manager.nix`**: Refactored `home-manager.users` to use `imports` blocks. This enables other NixOS modules to inject additional Home Manager configurations (like DMS) without modifying the main `home.nix`.
*   **Niri and DMS Configuration**:
    *   **`dotfiles/common/modules/desktop-environments/niri.nix`**:
        *   Imported the DMS Home Manager module (`inputs.dms.homeModules.dank-material-shell`).
        *   Enabled DMS for users `bosko` and `natty` via `programs.dank-material-shell.enable = true`.
        *   Cleaned up `environment.systemPackages` by commenting out utilities now provided by DMS (Waybar, Rofi, Swaylock, Mako) and added `fuzzel`.

## Recent Modifications (as of April 7, 2026)

### Virtualisation and Kubernetes Integration

*   **Kubernetes Support**:
    *   **`dotfiles/common/modules/virtualisation.nix`**: 
        *   Implemented a local Kubernetes cluster configuration with both `master` and `node` roles enabled.
        *   Configured `api.kube` host resolution and automated certificate management via `easyCerts`.
        *   Enabled CoreDNS as a Kubernetes addon.
        *   Added `kubernetes` and `kompose` to the system package set.
*   **Virtualisation Refinement**:
    *   Restructured the module for better readability and modularity.
    *   Ensured consistent `podman` and `libvirtd` configurations.
    *   Added users to the `podman` group in `dotfiles/common/modules/users.nix` for rootless container management.

### Application Updates

*   **Messaging**:
    *   Added `element-desktop` to the common desktop applications (documented via recent commits).
*   **System Status**:
    *   Successfully rebuilt and activated the `gaming` host configuration.

## Recent Modifications (as of April 6, 2026)

### Application and Tooling Updates

*   **Virtualisation and Containers**:
    *   **`dotfiles/common/modules/virtualisation.nix`**: 
        *   Added `kubectl` to the system package set for container orchestration.
        *   Enabled `podman` with `dockerCompat` to provide a Docker-compatible container engine.
        *   Configured container registry search paths to include `docker.io` and `quay.io`.
*   **System Packages**:
    *   **`dotfiles/gaming/environment.nix`**, **`dotfiles/laptop/environment.nix`**: Added `github-desktop` to provide a GUI for Git operations.
*   **Shell and CLI Improvements**:
    *   **`dotfiles/common/modules/shell.nix`**:
        *   Added `fzf` (fuzzy finder) and `zoxide` (smarter cd command) to the system package set.
        *   Enabled `zoxide` with Zsh integration for faster directory navigation.
        *   Further standardized shell aliases by adding `ls = "eza"`.
*   **Flake Maintenance**:
    *   Updated `flake.lock` to reflect latest upstream changes.

## Recent Modifications (as of April 2, 2026)

### Application and System Configuration Updates

*   **qBittorrent Integration**:
    *   **`dotfiles/gaming/environment.nix`**, **`dotfiles/laptop/environment.nix`**: Enabled qBittorrent as a service and added it to the system package set for both gaming and laptop configurations.
*   **Shell and CLI Improvements**:
    *   **`dotfiles/common/modules/shell.nix`**:
        *   Added `eza` for better file listing and configured shell aliases (`la`, `ll`, `lla`) to use it.
        *   Removed `sudo` from the `update` shell alias for consistent behavior.
        *   Refined the `cleanup` alias output formatting for a cleaner user experience.
*   **Home Manager and Dependency Fixes**:
    *   **`dotfiles/common/configs/home.nix`**: Commented out `claude-code` from the user's package set due to a dependency failure.

### Configuration Stabilization and Fixes

*   **`flake.nix` Formatting**:
    *   Reformatted `flake.nix` for improved readability and consistent structural layout.
*   **Helix Configuration Fix**:
    *   **`dotfiles/common/configs/helix.nix`**: Migrated deprecated `nodePackages` to top-level package names (`prettier`, `typescript-language-server`) to resolve system rebuild and evaluation errors.

### Shell, Editor, and UX Refinement

*   **Helix Editor Integration**:
    *   Switched the default system editor from `micro` to `helix`.
    *   Modularized Helix configuration into `dotfiles/common/configs/helix.nix`.
    *   Configured Helix with custom themes, LSP support (`nil`, `nixd`), and improved file type handling.
    *   Updated `EDITOR` and `VISUAL` environment variables to `hx`.
*   **Shell and Aliases**:
    *   **`dotfiles/common/modules/shell.nix`**: Added `direnv` and `nix-direnv` for automatic environment loading.
    *   Standardized shell aliases (`cleanup`, `dry-run`, `rebuild`, `update`) to include consistent punctuation and clear messaging.
    *   Added various CLI utilities including `nix-health`, `nix-init`, `nix-tree`, and `yazi`.
*   **Home Manager Cleanup**:
    *   Alphabetized package lists in `dotfiles/common/configs/home.nix` for better maintainability.

### Application and Virtualization Updates

*   **Browsers and Communication**:
    *   Added `tor-browser` to the system packages in `laptop/environment.nix`.
    *   Integrated `zen-browser` as a Flatpak application for the laptop.
*   **Virtualization and Containers**:
    *   **`dotfiles/common/modules/virtualisation.nix`**: Enabled `podman` and `podman-desktop` alongside the existing libvirt configuration.
*   **Flatpak Integration**:
    *   Added `albion-online` and `zen-browser` to the managed Flatpak packages.
    *   Removed legacy shell aliases that were previously used to launch these applications before their transition to Flatpak.

## Recent Modifications (as of March 8, 2026)

### Configuration Stabilization and Bug Fixes

*   **`flake.nix` Refactoring**:
    *   Removed redundant module imports (`nix.nix`, `users.nix`, `shell.nix`) from the `mkSystem` helper function. These are now correctly inherited via `commonModules`.
    *   Added the missing `dotfiles/common/modules/home-manager.nix` to `desktopModules` to ensure user-level configurations and dotfiles are properly applied during system builds.
*   **Server Host Stabilization**:
    *   Created a placeholder `dotfiles/server/hardware-configuration.nix` to resolve flake evaluation errors when performing flake-wide checks.
*   **Virtualisation Module Fix**:
    *   **`dotfiles/common/modules/virtualisation.nix`**: Added a systemd service override for `virt-secret-init-encryption.service` to correct a hardcoded `/usr/bin/sh` path, which was causing rebuild failures on NixOS. The service now correctly uses `${pkgs.bash}/bin/sh`.

## Recent Modifications (as of March 4, 2026)

### Emulation and Gaming Module Updates

*   **`dotfiles/common/modules/emulation.nix`**:
    *   Added `it.mijorus.gearlever` (Gear Lever) to the list of Flatpak packages.
*   **`dotfiles/common/modules/gaming.nix`**:
    *   Added `faugus-launcher` and `r2modman` to the list of gaming packages in `environment.systemPackages`.
    *   Added `mangojuice` to the list of gaming packages.
    *   Added `PROTON_FSR4_UPGRADE = "1";` to the `extraEnv` for Steam to enable FSR 4.

## Recent Modifications (as of February 16, 2026)

This section summarizes recent changes made to the NixOS configuration.

### Desktop Environment Modules

New modules for various desktop environments have been introduced under `dotfiles/common/modules/desktop-environments/`. For each, a module was created, temporarily integrated into the `laptop` configuration for dry-run testing, and then its integration removed (the module file itself was kept unless noted otherwise).

*   **`hyprland.nix`**: Configures the Hyprland compositor. Includes basic enablement and common Wayland companion packages. A previous change had uncommented GDM configuration within this file.
*   **`niri.nix`**: Configures the Niri compositor. Includes basic enablement and common Wayland companion packages.
*   **`plasma.nix`**: Configures the KDE Plasma desktop environment. Initially had a syntax error in `environment.systemPackages` (incorrect `kdePackages = { ... };` syntax), which was corrected.
*   **`cosmic.nix`**: Configures the Cosmic desktop environment. Initially had an "undefined variable 'cosmic-epoch'" error for a package, which was resolved by removing the `environment.systemPackages` entry entirely, as Cosmic DE is primarily enabled via services.
*   **`gnome.nix`**: Configures the GNOME desktop environment. Initially caused a conflict with SDDM (`services.displayManager.defaultSession`) and had incorrect package references (`gnome.gnome-terminal` instead of `pkgs.gnome-terminal`). Both were fixed by temporarily commenting out `defaultSession` in `laptop/environment.nix` and correcting package paths.
*   **`xfce.nix`**: Configures the XFCE desktop environment. Initially had an "option does not exist" error for `services.desktopManager.xfce`, which was fixed by correcting the path to `services.xserver.desktopManager.xfce`. Also had evaluation warnings for `xfce.<package>` references, suggesting direct `pkgs.<package>` usage. **During a dry-run on the `laptop`, an "error: path '/nix/store/.../xfce.nix' does not exist" occurred when importing `xfce.nix` from `laptop/environment.nix`. This was resolved by importing `xfce.nix` directly into the `laptop`'s `modules` list in `flake.nix` using `${self}/dotfiles/common/modules/desktop-environments/xfce.nix`, replacing the previous `cosmic.nix` entry.**
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
4.  To enable it for a specific machine (e.g., `laptop`), add an `imports` statement to that machine's `flake.nix` for temporary testing, or permanently in its `environment.nix`. Always use the `${self}/...` path for modules defined within this flake.
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
      ../../common/modules/desktop-environments/my-de.nix
    ];
    ```
5.  Perform a `nixos-rebuild dry-run --flake .#<machine-name>` to verify the configuration, debugging any errors.
6.  If necessary, temporarily comment out conflicting display manager settings (e.g., `services.displayManager.defaultSession`) in the machine's `environment.nix` during testing.
7.  The desktop environment module file (`my-de.nix`) is typically kept after testing for future reference.