---
name: nix-repl
description: Use this skill when the user wants to "open nix repl", "nix repl", "explore flake", "inspect config", or "repl for X host". Opens a nix repl with the flake loaded for interactive exploration of any host's configuration.
model: haiku
version: 0.2.0
---

# Nix REPL — Interactive Flake Exploration

Open a nix repl pre-loaded with this repo's flake so the user can interactively explore any host's configuration options, packages, and derivations.

## Arguments

Parse from the user's request:

- **`<host>`** (optional) — one of the four flake hosts `gaming`, `laptop`, `natalie-laptop`, `vpn-server` (the valid set is `.flakeHosts` in `/home/bosko/NixOS/.claude/hosts.json`). Aliases `natalie` → `natalie-laptop`, `vpn`/`oracle`/`server` → `vpn-server` are accepted (same alias set as `resolve-host.sh`). If omitted, ask in Step 1.

## Step 1 — Resolve the target host

If the user named a host (e.g. `/nix-repl gaming`), use it. Otherwise present the host pick via the **AskUserQuestion tool** with one option per flake host (`gaming`, `laptop`, `natalie-laptop`, `vpn-server`) rather than asking in free-form prose. Skip the question if the user already named a host.

Accept short aliases: `natalie` → `natalie-laptop`, `vpn`/`oracle`/`server` → `vpn-server` (matches `.claude/lib/resolve-host.sh`'s alias table). The valid host set is `.flakeHosts` in `/home/bosko/NixOS/.claude/hosts.json` — these are the only keys under `nixosConfigurations`.

## Step 2 — Print the repl command

Since nix repl is an interactive session that cannot be driven headlessly, print the exact command for the user to run in their own terminal:

```
Run this in a terminal:

  nix repl --expr 'builtins.getFlake "path:/home/bosko/NixOS"'

Then inside the repl, bind the host config for easy access:

  cfg = nixosConfigurations.<host>.config

Example queries for <host>:
  cfg.networking.hostName
  cfg.environment.systemPackages
  cfg.services.openssh.enable
  cfg.home-manager.users.bosko.programs.helix.enable
  builtins.attrNames cfg.systemd.services
```

Substitute `<host>` with the resolved host name from Step 1.

## Step 3 — Provide useful starting expressions

Give the user 5–8 ready-to-paste expressions tailored to the host they chose:

### All hosts
- `cfg.networking.hostName` — confirm which host you're looking at
- `cfg.system.stateVersion` — state version
- `builtins.attrNames cfg.services` — list all enabled service namespaces
- `cfg.environment.systemPackages` — list system packages

### Desktop hosts (gaming, laptop, natalie-laptop)
- `cfg.services.displayManager.defaultSession` — active desktop session
- `cfg.home-manager.users.bosko.programs` — bosko's HM programs
- `builtins.attrNames cfg.services.flatpak` — flatpak status

### gaming only
- `cfg.hardware.nvidia` — NVIDIA driver config
- `cfg.programs.steam` — Steam config

### vpn-server only
- `cfg.networking.wg-quick.interfaces.wg0` — WireGuard interface config

## Step 4 — Explain tab-completion

Note that nix repl supports **tab completion** — type `cfg.` and press Tab to explore available attributes interactively. Attrsets can be drilled into with `.` notation.

---

## Key facts

- The flake path is always `path:/home/bosko/NixOS` — using `path:` forces Nix to read from disk rather than a cached evaluation.
- Nix repl is fully interactive and cannot be run by Claude directly — always give the user the command to run themselves.
- `:q` exits the repl; `:r` reloads the flake after changes.
- `:p <expr>` pretty-prints a value (useful for large attrsets).
