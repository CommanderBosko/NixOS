# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Skill Awareness

If you notice you've performed the same multi-step task twice in a session — or if a task involved 4+ steps that could be cleanly reused — proactively offer to create a skill for it. Say something like: "I've done this a few times now — want me to create a skill so you can invoke it with a single phrase?" If the user agrees, invoke the `new-skill` skill to build it interactively. Prefer project-local scope for NixOS-specific workflows, global scope for general-purpose utilities.

## Scope First (Interview)

Before you do any work, use the `/interview` skill to pin down the real goal with me — don't start building from a fuzzy or assumed understanding of the request. Surface the unknowns, confirm scope and constraints, and only proceed once the target is clear. Do this in tandem with the Verification Plan below: the interview establishes *what* we're building and how we'll know it's done, and the verification plan establishes *how we'll prove* it works. Lay out both together, up front, before touching the config.

## Verification Plan

Before you do any work, mention how you could verify the work with the `/verify` skill — state up front how you'll confirm each part actually works before calling it done. For changes to this repo that usually means a `nh os boot /home/bosko/NixOS --dry` (or `flake-check`) to prove the config still evaluates, plus whatever host-specific check applies (service status, journal logs, a rebuild on the affected host). Lay out the plan with the work, not after it.

## Parallelize with Sub-Agents

**This rule is your standing authorization to spawn sub-agents — you do not need to ask first.** Once scope and the verification plan are set, before starting any task with more than one independent part, stop and run a parallelization check. This is a required step, not an aspiration: ask "Can I split this into pieces that don't depend on each other's output?" If yes, spawn one sub-agent per piece in a single message and let them run concurrently.

Trigger parallelization whenever you hit any of these:
- About to research, search, or read across 2+ areas of the tree that don't depend on each other.
- About to scaffold or draft 2+ files/modules whose *contents* don't reference each other (e.g. separate DE modules, changes across multiple hosts).
- You catch yourself planning "do A, then B, then C" where B doesn't need A's result.

Reserve serial work for genuine dependencies — e.g. a new module and the `flake.nix` line that imports it, or a module plus the `environment.nix` that configures it, are coupled, so keep them together. When the pieces are independent, default to fanning out breadth-first; state in your plan which pieces run in parallel and why.

## Use Existing Skills First

Before doing a task by hand, check whether an existing skill already covers it and invoke it instead of improvising. This repo ships many task-specific skills (`add-package`, `add-flatpak`, `flake-check`, `nixos-dry-run`, `ssh-host`, `journal`, `update`, `verify-service`, and more) — prefer them over ad-hoc steps so the agreed, repeatable workflow is followed. If you find yourself doing the same multi-step task a second time and no skill exists, offer to create one (see Skill Awareness above).

## Editing Claude Skills

The global Claude Code skills (`interview`, `new-skill`, `git-commit`, `git-push`, `repo-creator`, `session-closer`, `search-pkg`) are **owned by this repo**, not by `~/.claude`. Source lives in `dotfiles/bosko/claude/skills/<name>/SKILL.md`; `dotfiles/bosko/bosko-claude.nix` symlinks each one into `~/.claude/skills/<name>/SKILL.md` via Home Manager `home.file`.

- **Always edit the repo copy** under `dotfiles/bosko/claude/skills/`. The `~/.claude/skills/` path is a read-only `/nix/store` symlink — editing it directly is impossible, and the change wouldn't survive a rebuild anyway.
- A new skill must be added to the `home.file` list in `bosko-claude.nix`, then rebuilt before its symlink appears.
- Edits to an existing skill's `SKILL.md` only take effect in `~/.claude` after a rebuild (`nh os boot /home/bosko/NixOS`); the live session keeps using the old store path until then.

## Common Commands

```bash
# Stage a rebuild for next boot (activate by rebooting)
nh os boot /home/bosko/NixOS

# Dry-run (see what would change without applying)
nh os boot /home/bosko/NixOS --dry

# Update all flake inputs
nix flake update

# Garbage collect old generations (keeps 3 builds)
nh clean all --keep 3
```

These are also available as shell aliases when running as bosko: `rebuild`, `dry-run`, `update`, `cleanup`.

## Architecture Overview

Single-flake NixOS config for four hosts: `gaming`, `laptop`, `natalie-laptop`, `vpn-server`. Shared modules live under `dotfiles/common/`; host-specific files live under `hosts/<hostname>/`.

### Module Composition

`flake.nix` defines a `lib.mkSystem` helper that composes module lists per host:

- **`commonModules`** — base for all hosts: bootloader, firmware, fonts, localisation, nix settings, shell, users, security
- **`desktopModules`** — `commonModules` + home-manager, nix-flatpak, audio, emulation, SDDM; used by gaming, laptop, and natalie-laptop
- Each host then adds its own desktop environment, `hardware-configuration.nix`, `environment.nix`, `networking.nix`, and any host-specific modules (`amd.nix`, `nvidia.nix`, `gaming.nix`, etc.)

`nvidia.nix` is imported explicitly per desktop host (not via `desktopModules`) to allow the gaming host to drop it independently when the AMD card is installed. `amd.nix` and `gaming.nix` are gaming-only.

The vpn-server uses only `commonModules` + disko on `aarch64-linux` (headless, no flatpaks, no DE).

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
    ├── bosko-claude.nix  # Symlinks Claude skills into ~/.claude/skills/ + plugin/settings activation
    └── claude/skills/    # Claude Code skill files (one dir per skill, each with SKILL.md)

hosts/
├── gaming/               # hardware-configuration.nix, environment.nix, networking.nix
├── laptop/               # same three files
├── natalie-laptop/       # same three files
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
