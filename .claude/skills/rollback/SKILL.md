---
name: rollback
description: Use this skill when the user wants to "rollback", "roll back nixos", "revert to previous generation", "undo last rebuild", "go back to previous build", or "nixos rollback". It shows recent generations, confirms with the user, then activates the previous generation immediately via nixos-rebuild switch --rollback.
version: 0.1.0
---

# NixOS Rollback

Roll the system back to the previous NixOS generation. This activates the previous generation immediately — no reboot required.

## Step 1 — Show recent generations

Run:

```bash
sudo nix-env --list-generations --profile /nix/var/nix/profiles/system
```

Display the last 5 generations in a compact table. Mark the current generation clearly (it has `(current)` in the output). Identify the generation that rollback will activate (current number minus 1).

Example display:

```
Generation  Date                  Current
----------  --------------------  -------
42          2026-05-18 14:32:11
43          2026-05-19 09:15:44
44          2026-05-19 21:03:02
45          2026-05-20 10:47:55   <-- current
```

Rollback will activate: **generation 44**

## Step 2 — Confirm

Ask the user to confirm before proceeding. State clearly:

- Which generation is currently active
- Which generation will become active after rollback
- That this takes effect immediately (no reboot needed)
- That rollback is reversible by running `/rollback` again or by rebuilding

Do not proceed until the user explicitly confirms (e.g. "yes", "do it", "go ahead").

## Step 3 — Run rollback

```bash
sudo nixos-rebuild switch --rollback
```

The `nh` tool does not have a rollback subcommand — always use `nixos-rebuild` directly. Do not add `--dry` or any other flags.

## Step 4 — Report result

Run again to confirm the active generation changed:

```bash
sudo nix-env --list-generations --profile /nix/var/nix/profiles/system | tail -5
```

Show the user which generation is now marked `(current)` and confirm the rollback succeeded.

---

## Key constraints

- No dry-run mode — rollback either happens or it doesn't.
- Use `nixos-rebuild switch --rollback` — not `nh`, not `nixos-rebuild boot --rollback`.
- `switch --rollback` activates immediately; it does NOT require a reboot.
- If the user wants to roll back further than one generation, they can run `/rollback` again after this one completes.
- If rollback fails (e.g. no previous generation exists), report the error output and stop — do not attempt workarounds.
