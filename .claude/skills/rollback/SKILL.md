---
name: rollback
description: Use this skill when the user wants to "rollback", "roll back nixos", "revert to previous generation", "undo last rebuild", "go back to previous build", or "nixos rollback". It shows recent generations, confirms with the user, then activates the previous generation immediately via nixos-rebuild switch --rollback.
model: haiku
version: 0.3.0
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

Present the confirmation as a hard gate via the **AskUserQuestion tool**, with exactly two
options: **Roll back to gen N** (proceed) and **Cancel** (abort, do nothing). Do not use
free-form prose or a typed-`YES` match for this gate. State clearly:

- Which generation is currently active
- Which generation will become active after rollback
- That this takes effect immediately (no reboot needed)
- That rollback is reversible by running `/rollback` again or by rebuilding

Do not proceed until the user picks **Roll back to gen N**.

## Step 3 — Hand off the rollback command

**Do not run this via the Bash tool.** `sudo` has no NOPASSWD rule on this host, so it will fail with "a terminal is required to read the password" (see Gotchas). Print the exact command and ask the user to run it themselves (suggest the `!` prefix):

```bash
sudo nixos-rebuild switch --rollback
```

Do not add `--dry` or any other flags. Wait for the user to confirm it completed before moving to Step 4.

## Step 4 — Report result

Re-run the same read-only helper from Step 1 to confirm the active generation changed — no sudo needed:

```bash
/home/bosko/NixOS/.claude/skills/rollback/scripts/rollback.sh
```

Show the user which generation is now marked `<- current` and confirm the rollback succeeded.

## Script

`.claude/skills/rollback/scripts/rollback.sh [target-generation]` — **read-only**: lists recent
generations and resolves the rollback target (current minus 1, or the number passed). It does NOT
activate anything; the actual `nixos-rebuild switch --rollback` (Step 3) is always handed off to
the user to run themselves, never executed by Claude directly.

---

## Key constraints

- No dry-run mode for this flow — rollback either happens or it doesn't. (`nh os rollback` does
  have a `--dry` flag, but this skill deliberately stays on the `nixos-rebuild`-direct flow that's
  been proven across 9+ past sessions — see Gotchas.)
- Use `nixos-rebuild switch --rollback` — not `nixos-rebuild boot --rollback`.
- `switch --rollback` activates immediately; it does NOT require a reboot.
- If the user wants to roll back further than one generation, they can run `/rollback` again after this one completes.
- If rollback fails (e.g. no previous generation exists), report the error output and stop — do not attempt workarounds.

## Gotchas

- **`sudo` has no NOPASSWD rule on this host — it always needs an interactive password.** Running `sudo nixos-rebuild switch --rollback` directly via the Bash tool will fail with "a terminal is required to read the password" (observed across 9+ past sessions). Instead, tell the user the exact command to run themselves (suggest the `!` prefix), or ask them to run it — don't attempt it and then report failure.
- **This skill's "`nh` has no rollback subcommand" claim was wrong and has been removed** (corrected 2026-08-09 skill-audit sweep). `nh os rollback --to <gen>` genuinely exists (`nh 4.4.1`, confirmed via `nh os rollback --help`) and maps directly onto this skill's own generation-target argument. It's not adopted here only because the `nixos-rebuild`-direct flow above is the one actually proven across 9+ past sessions on this host — not because `nh` doesn't work. Same NOPASSWD hand-off constraint applies to either command.
