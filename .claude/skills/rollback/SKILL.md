---
name: rollback
description: Use this skill when the user wants to "rollback", "roll back nixos", "revert to previous generation", "undo last rebuild", "go back to previous build", or "nixos rollback". It shows recent generations, confirms with the user, then activates the previous generation immediately via nixos-rebuild switch --rollback.
version: 0.2.0
---

# NixOS Rollback

Roll the system back to the previous NixOS generation. This activates the previous generation immediately — no reboot required.

## Arguments

- **Target generation** (optional) — a specific generation number to roll back to. If omitted,
  the target is the current generation minus 1.

## Step 1 — List generations and resolve the target

Run the read-only helper. It lists the last 5 generations, marks the current one, and prints the
rollback target (current minus 1, or the number you pass):

```bash
/home/bosko/NixOS/.claude/skills/rollback/scripts/rollback.sh [target-generation]
```

The script only reads — it does **not** activate anything. Show the user the listing, the current
generation, and the resolved rollback target.

## Step 2 — Confirm

Ask the user to confirm before proceeding. This yes/no gate can be presented via the
**AskUserQuestion tool** (e.g. "Roll back to gen N" / "Cancel"). State clearly:

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

## Script

`.claude/skills/rollback/scripts/rollback.sh [target-generation]` — **read-only**: lists recent
generations and resolves the rollback target (current minus 1, or the number passed). It does NOT
activate anything; the skill runs the actual `nixos-rebuild switch --rollback` itself (Step 3)
only after the user confirms.

---

## Key constraints

- No dry-run mode — rollback either happens or it doesn't.
- Use `nixos-rebuild switch --rollback` — not `nh`, not `nixos-rebuild boot --rollback`.
- `switch --rollback` activates immediately; it does NOT require a reboot.
- If the user wants to roll back further than one generation, they can run `/rollback` again after this one completes.
- If rollback fails (e.g. no previous generation exists), report the error output and stop — do not attempt workarounds.

## Gotchas

- **`sudo` has no NOPASSWD rule on this host — it always needs an interactive password.** Running `sudo nixos-rebuild switch --rollback` directly via the Bash tool will fail with "a terminal is required to read the password" (observed across 9+ past sessions). Instead, tell the user the exact command to run themselves (suggest the `!` prefix), or ask them to run it — don't attempt it and then report failure.
