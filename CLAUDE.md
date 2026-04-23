# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Common Commands

```bash
# Rebuild and switch the current host
nh os switch /home/bosko/NixOS

# Dry-run (see what would change without applying)
nh os switch /home/bosko/NixOS --dry

# Update all flake inputs
nix flake update

# Garbage collect old generations
sudo nix-collect-garbage -d
```

These are also available as shell aliases when running as bosko: `rebuild`, `dry-run`, `update`, `cleanup`.

## Architecture Overview

Single-flake NixOS config for three hosts: `gaming`, `laptop`, `server`. All configuration lives under `dotfiles/`.

### Module Composition

`flake.nix` defines a `lib.mkSystem` helper that composes module lists per host:

- **`commonModules`** — base for all hosts: bootloader, firmware, fonts, localisation, nix settings, shell, users
- **`desktopModules`** — `commonModules` + home-manager, nix-flatpak, amd, nvidia, audio, emulation, virtualisation, SDDM; used by gaming and laptop
- Each host then adds its own desktop environment, `hardware-configuration.nix`, `environment.nix`, and `networking.nix`

The server host uses only `commonModules` (headless, no flatpaks, no DE).

### Directory Layout

```
dotfiles/
├── common/
│   ├── modules/          # System-level NixOS modules
│   │   ├── desktop-environments/   # 11 swappable DE modules (niri, plasma, etc.)
│   │   └── *.nix         # bootloader, shell, users, amd, nvidia, sddm, …
│   └── configs/          # Home Manager configs shared by both users
│       ├── home.nix      # HM root — imported by both bosko and natty
│       ├── helix.nix
│       └── dotfiles (katerc, kitty.conf, starship.toml)
├── gaming/               # hardware-configuration.nix, environment.nix, networking.nix
├── laptop/               # same three files
└── server/               # same three files
```

### Key Patterns

- **Home Manager** runs as a NixOS module. Both users (`bosko` and `natty`) import the same `dotfiles/common/configs/home.nix`. DE modules extend HM config for Dank Material Shell on the laptop.
- **Desktop environments** are pluggable — swap by changing which DE module is imported in the host's flake entry.
- **Flatpaks** are managed declaratively via `nix-flatpak`; defined per-host in `environment.nix`.
- **System architecture** is `x86_64-linux` throughout; state version `25.11`.
- `nix-ld` is enabled only on gaming for binary compatibility.
- Gaming: Plasma 6 / X11+Wayland. Laptop: Niri + Dank Material Shell / Wayland.

### Users

- `bosko` — primary user, wheel/sudo, Nix trusted user, auto-login, extra package: mumble
- `natty` — secondary user, same groups, extra package: gimp

Both users share the same Home Manager config.

### Flake Inputs / specialArgs

Flake inputs (`home-manager`, `nix-flatpak`, `dms`) are defined once in `flake.nix` and passed to modules via `specialArgs`, ensuring consistency across hosts.

### Security Module (`dotfiles/common/modules/security.nix`)

Part of `commonModules` (applies to all hosts). Enables:

- AppArmor MAC enforcement (`security.apparmor.enable`, `killUnconfinedConfinables`)
- Linux audit daemon + kernel `audit=1` parameter
- D-Bus AppArmor mediation
- PAM wheel-group enforcement for sudo
- Kernel image protection / kexec disabled
- Full ASLR (`kernel.randomize_va_space = 2`)

**nixpkgs bug workaround:** AppArmor's PAM integration rejects non-absolute module paths. SDDM uses `include` directives (e.g. `include login`) which are service-name references, not `.so` paths. The fix uses `lib.mkForce` to clear the `rules` attrset for `sddm` and `sddm-autologin` and provides `text` overrides that preserve identical PAM behaviour. The `sddm-autologin` auth module paths use `pkgs.linux-pam` to stay correct across updates.

### Adding a New Desktop Environment

1. Create `dotfiles/common/modules/desktop-environments/my-de.nix`
2. Add it to git: `git add dotfiles/common/modules/desktop-environments/my-de.nix`
3. Import in the host's flake entry using `"${self}/dotfiles/common/modules/desktop-environments/my-de.nix"`
4. Test with `nh os switch /home/bosko/NixOS --dry`
5. If there are display manager conflicts, temporarily comment out `services.displayManager.defaultSession` in the host's `environment.nix`
