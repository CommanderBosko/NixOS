# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## /init Also Runs claude-rules

Whenever `/init` is run in this repo, invoke the `claude-rules` skill immediately after `/init` finishes generating or updating `CLAUDE.md` — don't treat `/init` as done until that check has run. This ensures the five standing rules below are present (and restored if `/init`'s own pass ever stripped or reworded them) every time `/init` touches this file.

## Skill Awareness

If you notice you've performed the same multi-step task twice in a session — or if a task involved 4+ steps that could be cleanly reused — proactively offer to create a skill for it. Say something like: "I've done this a few times now — want me to create a skill so you can invoke it with a single phrase?" If the user agrees, invoke the `new-skill` skill to build it interactively. Prefer project-local scope for NixOS-specific workflows, global scope for general-purpose utilities.

## Scope First (Interview)

Before you do any work, use the `/interview` skill to pin down the real goal with me — don't start building from a fuzzy or assumed understanding of the request. Surface the unknowns, confirm scope and constraints, and only proceed once the target is clear. Do this in tandem with the Verification Plan below: the interview establishes *what* we're building and how we'll know it's done, and the verification plan establishes *how we'll prove* it works. Lay out both together, up front, before touching the config. All interview questions and decision confirmations go through the **AskUserQuestion** tool (see Ask via AskUserQuestion below), not plain-text prose.

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

Before doing a task by hand, check whether an existing skill already covers it and invoke it instead of improvising — this repo ships many task-specific skills under `.claude/skills/` (project-local) and `dotfiles/bosko/claude/skills/` (global); check those directories rather than assuming from memory, since the roster changes over time. Prefer them over ad-hoc steps so the agreed, repeatable workflow is followed. If you find yourself doing the same multi-step task a second time and no skill exists, offer to create one (see Skill Awareness above).

## Ask via AskUserQuestion

When you need a decision, choice, or clarification from the user — not just information you can look up yourself — use the **AskUserQuestion** tool rather than asking in plain text. Phrase it as 2-4 concrete options (with a recommended one first); when the answer could be open-ended, the tool's built-in "Other" choice covers free text. This keeps answers structured, makes trade-offs explicit, and avoids an answer getting buried in prose. Reserve plain-text questions for genuinely open, generative prompts where no sensible options exist yet (e.g. "describe the project in your own words").

## Editing Claude Skills

The global Claude Code skills are **owned by this repo**, not by `~/.claude`. Source lives in `dotfiles/bosko/claude/skills/<name>/SKILL.md`; `dotfiles/bosko/bosko-claude.nix` symlinks each one into `~/.claude/skills/<name>/SKILL.md` via Home Manager `home.file`.

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

## Commit Style

Conventional commits: `type(scope): short description` — lowercase after the colon, no trailing period, under 72 characters, focused on what changed and why.

- **Types:** `feat`, `fix`, `refactor`, `chore`, `docs`, `style`, `test`, `perf`
- **Scopes:** the affected area of the repo — e.g. `gaming`, `laptop`, `security`, `skills`, `vpn`, `memory`, `flake`, `shell`, `users`. Use the most specific scope that fits; if several unrelated scopes are touched, pick the dominant one or drop the scope.
- Session closes use `chore(session): end-of-day close YYYY-MM-DD — <brief summary>`.

## Architecture Overview

Single-flake NixOS config for four hosts: `gaming`, `laptop`, `natalie-laptop`, `vpn-server`. Shared system modules live under `modules/` (including `desktop-environments/`, the swappable DE modules); shared Home Manager configs under `dotfiles/` (`common/` shared by both users, `bosko/` for bosko-only HM config including the Claude skill sources); host-specific files under `hosts/<hostname>/` (`hardware-configuration.nix`, `environment.nix`, `networking.nix`, plus any host-only modules like `amd.nix`/`nvidia.nix`/`gaming.nix`). Run `ls modules/ dotfiles/ hosts/` for the current contents rather than trusting a stale tree here.

### Module Composition

`flake.nix`'s `mkSystem` helper (also exported as `lib.mkSystem`) builds each host from `{ name, system ? x86_64-linux, nixpkgs ? nixos-unstable, modules }`: it sets `networking.hostName` and injects the shared `specialArgs`, so each host entry in `flake.nix` holds only its unique module list. Module lists compose in layers:

- **`commonModules`** — base for all hosts: bootloader, firmware, fonts, localisation, nix settings, shell, users, security, sops
- **`desktopModules`** — `commonModules` + home-manager, nix-flatpak, audio, desktop-apps, desktop-networking, development, emulation, SDDM, vpn; used by gaming, laptop, and natalie-laptop
- Each host then adds its own desktop environment, hardware config, `environment.nix`/`networking.nix` (host-specific extras only), any host-only modules, and its `system.stateVersion` — **frozen at install time, never bump it on upgrades.**

`nvidia.nix` is imported explicitly per desktop host (not via `desktopModules`) so the gaming host can drop it independently when the AMD card is installed; `amd.nix`/`gaming.nix` are gaming-only. The vpn-server uses only `commonModules` + disko on `aarch64-linux` (headless, no DE, no flatpaks).

### Key Patterns

- `nix-ld` is enabled only on gaming, for binary compatibility — don't assume it's available elsewhere.
- **DE smoke checks**: `lib.deSmoke` in `flake.nix` exposes the laptop config with each DE module swapped in, so CI's weekly `de-smoke` job can deep-evaluate DE modules that no host currently imports — this is what keeps unused DE modules from rotting silently.
- Both `bosko` and `natty` import the same `dotfiles/common/configs/home.nix`; per-user package/state differences (auto-login, extra packages, stateVersion) live in `modules/users.nix` and `home-manager.nix`, not in the shared HM config.

### Security Module (`modules/security.nix`)

Part of `commonModules` (applies to all hosts): AppArmor, Linux audit daemon, PAM wheel-group enforcement, kexec/kernel-image protection, full ASLR. Current workarounds for nixpkgs/AppArmor bugs are documented as comments directly in that file — read them there rather than here, since this doc drifts out of sync with the actual fix faster than the source does.

### Adding a New Desktop Environment

Use the `new-module` skill to scaffold `modules/desktop-environments/<name>.nix` and wire it into a host's flake entry. The gotcha: a normal `nh os boot --dry` only exercises whichever DE the target host already has wired in, so it silently verifies nothing about a module not currently imported by any host (true for most of them). Use the `de-smoke-check` skill instead — it deep-evaluates that module's `lib.deSmoke` build graph directly, catching real eval errors a shallow dry-run would miss.
