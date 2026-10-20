# AGENTS.md

Read-only orientation for local agents (Hermes). Claude Code reads `CLAUDE.md`.

## Rules
- Check the premise before diagnosing. If a file, option or service the user names doesn't exist, say so instead of inventing a fix.
- You may not edit this repo. Propose changes as text; the user applies them.
- Don't guess flake URLs or `nix run` unknown GitHub flakes. Use the `nix` MCP tool (`channel` parameter picks the nixpkgs channel) for package and option facts.
- Cite only pages you actually opened. Don't give version tags from memory.

## NixOS gotchas
- `nh os boot` stages a rebuild for the next boot; `nh os switch` activates it now. Rebuilds are the user's call, never yours.
- Overriding a module's `wantedBy` needs `lib.mkForce [ ]`, a plain `[ ]` merges with the default.
- `nix flake check` is shallow; deep-eval `nixosConfigurations.<host>.config.system.build.toplevel.drvPath`.
- `system.stateVersion` is frozen at install time, never bump it.

## Layout
- `flake.nix` composes four hosts: `gaming`, `laptop`, `natalie-laptop`, `vpn-server`.
- `modules/` shared system modules, `dotfiles/` Home Manager, `hosts/<name>/` per-host files.
