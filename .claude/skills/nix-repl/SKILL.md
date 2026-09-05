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

Since nix repl is an interactive session that cannot be driven headlessly, read `assets/repl-examples.md` (relative to this skill's directory) and print it to the user with every `<host>` placeholder substituted for the resolved host name from Step 1.

## Step 3 — Provide useful starting expressions

`assets/repl-examples.md` already groups example queries by host applicability (All hosts / Desktop hosts / gaming only / vpn-server only) — present only the sections that apply to the resolved host (All hosts always; plus the matching desktop/gaming/vpn-server section).

## Step 4 — Explain tab-completion

Note that nix repl supports **tab completion** — type `cfg.` and press Tab to explore available attributes interactively. Attrsets can be drilled into with `.` notation.

---

## Key facts

- The flake path is always `path:/home/bosko/NixOS` — using `path:` forces Nix to read from disk rather than a cached evaluation.
- Nix repl is fully interactive and cannot be run by Claude directly — always give the user the command to run themselves.
- `:q` exits the repl; `:r` reloads the flake after changes.
- `:p <expr>` pretty-prints a value (useful for large attrsets).

## Assets

- `assets/repl-examples.md` — the repl launch command plus host-categorized example queries. Read it in Steps 2–3 and substitute `<host>` for the resolved host name.
