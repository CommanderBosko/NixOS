# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Common Commands

```bash
# Stage a rebuild for next boot (activate by rebooting)
nh os boot /home/bosko/NixOS

# Dry-run (see what would change without applying)
nh os boot /home/bosko/NixOS --dry

# Update all flake inputs
nix flake update

# Garbage collect old generations (keeps 3 builds)
sudo nix-collect-garbage -d
```

These are also available as shell aliases when running as bosko: `rebuild`, `dry-run`, `update`, `cleanup`.

## Architecture Overview

Single-flake NixOS config for five hosts: `gaming`, `laptop`, `server`, `natalie-laptop`, `vpn-server`. Shared modules live under `dotfiles/common/`; host-specific files live under `hosts/<hostname>/`.

### Module Composition

`flake.nix` defines a `lib.mkSystem` helper that composes module lists per host:

- **`commonModules`** — base for all hosts: bootloader, firmware, fonts, localisation, nix settings, shell, users, security
- **`desktopModules`** — `commonModules` + home-manager, nix-flatpak, audio, emulation, SDDM; used by gaming, laptop, and natalie-laptop
- Each host then adds its own desktop environment, `hardware-configuration.nix`, `environment.nix`, `networking.nix`, and any host-specific modules (`amd.nix`, `nvidia.nix`, `gaming.nix`, etc.)

`nvidia.nix` is imported explicitly per desktop host (not via `desktopModules`) to allow the gaming host to drop it independently when the AMD card is installed. `amd.nix` and `gaming.nix` are gaming-only.

The server host uses only `commonModules` (headless, no flatpaks, no DE). The vpn-server uses `commonModules` + disko on `aarch64-linux`.

### Directory Layout

```
dotfiles/
├── common/
│   ├── modules/          # System-level NixOS modules
│   │   ├── desktop-environments/   # 11 swappable DE modules (niri, plasma, cosmic, etc.)
│   │   └── *.nix         # bootloader, shell, users, amd, nvidia, gaming, sddm, security, …
│   └── configs/          # Home Manager configs shared by both users
│       ├── home.nix      # HM root — imported by both bosko and natty
│       ├── helix.nix
│       └── dotfiles (katerc, kitty.conf, starship.toml)
└── bosko/                # bosko-specific HM configs (not shared with natty)
    ├── bosko-claude.nix  # Symlinks Claude agents into ~/.claude/agents/
    └── claude/agents/    # Agent definition files (repo-creator-agent.md, session-closer.md)

hosts/
├── gaming/               # hardware-configuration.nix, environment.nix, networking.nix
├── laptop/               # same three files
├── natalie-laptop/       # same three files
├── server/               # same three files
└── vpn-server/           # configuration.nix, disko.nix, hardware-configuration.nix
```

### Key Patterns

- **Home Manager** runs as a NixOS module. Both users (`bosko` and `natty`) import the same `dotfiles/common/configs/home.nix`. User-specific HM state (username, homeDirectory, stateVersion) is set per-user in `home-manager.nix`.
- **Desktop environments** are pluggable — swap by changing which DE module is imported in the host's flake entry.
- **Flatpaks** are managed declaratively via `nix-flatpak`; defined per-host in `environment.nix`.
- **System architecture** is `x86_64-linux` throughout (vpn-server is `aarch64-linux`); state version `25.11`.
- `nix-ld` is enabled only on gaming for binary compatibility.
- Gaming: Plasma 6 / Wayland. Laptop: Niri / Wayland. Natalie-laptop: Cosmic / Wayland.

### Users

- `bosko` — primary user, wheel/sudo, Nix trusted user, auto-login; user packages: `claude-code`, `gemini-cli`
- `natty` — secondary user, wheel/sudo, Nix trusted user; user packages: none

Both users share the same Home Manager config. `mumble` is a system package on gaming only.

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
3. Import in the host's flake entry using `"${self}/dotfiles/common/modules/desktop-environments/my-de.nix"` (note: DE modules stay under `dotfiles/common/`, only host-specific files are under `hosts/`)
4. Test with `nh os boot /home/bosko/NixOS --dry`
5. If there are display manager conflicts, temporarily comment out `services.displayManager.defaultSession` in the host's `environment.nix`
