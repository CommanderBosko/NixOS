---
name: nixos-gc
description: This skill should be used when the user wants to "garbage collect", "clean up nix store", "free disk space", "remove old generations", "run nix gc", or "cleanup nixos". It permanently removes old Nix store paths and system generations that are no longer referenced.
version: 0.2.0
---

# NixOS Garbage Collection

Remove unreferenced Nix store paths and old system generations to free disk space. This is a HIGH-RISK, IRREVERSIBLE operation — deleted generations cannot be restored.

## Arguments

None. This skill takes no invocation-time inputs. It always keeps the 3 newest generations, the profile's current generation, and the booted and running generations, and collects the rest.

## Instructions

### Step 1 — Warn the user (mandatory)

Before running anything, present this warning clearly:

> "Garbage collection will permanently delete old NixOS generations and unreferenced store paths. This cannot be undone. You will no longer be able to roll back to the generations being removed."

### Step 2 — Preview what would be deleted (unprivileged, safe to run automatically)

Run `/home/bosko/NixOS/.claude/skills/nixos-gc/scripts/gc-preview.sh` and show the user its output. It reads generation info directly from
`/nix/var/nix/profiles/system-*-link` symlinks — no sudo required, and it deletes nothing. Its
`Would DELETE` line is the exact list `gc.sh` will act on, so the user confirms against a real list.

### Step 3 — Confirm with the user

Present the destructive confirmation as a hard gate via the **AskUserQuestion tool**, with exactly two options: **Proceed** (run garbage collection) and **Cancel** (abort, do nothing). Show the preview from Step 2 alongside it. Do not use free-form prose or a typed-`YES` match for this gate. This gate is mandatory even if the user's original phrasing sounded like a go-ahead — always require an explicit pick here because the operation is irreversible.

Wait for the response. If the user picks anything other than **Proceed**, abort — do not run the script.

### Step 4 — Hand off the actual deletion to the user

`scripts/gc.sh` (the destructive script) calls `sudo nix-env --list-generations`, `sudo nix-env
--delete-generations`, and `sudo nix-store --gc`. There is no NOPASSWD rule for `sudo` on the local desktop hosts (only vpn-server has passwordless sudo, and this skill never targets it),
so running `scripts/gc.sh` through the Bash tool will fail with "a password is required" — don't
attempt it and then report the failure.

Do NOT prefix the command with `!`. Claude Code's `!` runs without a terminal, so sudo fails with "a terminal is required to read the password". Instead, tell the user to open their own separate terminal and run:

```
/home/bosko/NixOS/.claude/skills/nixos-gc/scripts/gc.sh
```

Never suggest `sudo -S` or piping a password in.

### Step 5 — Report results

Once the user confirms it ran, re-run `/home/bosko/NixOS/.claude/skills/nixos-gc/scripts/gc-preview.sh` to confirm the old generations are
actually gone (its output will show only the generations that are kept). Ask the user for the
disk-space-freed line from their own terminal output, since Claude never sees it directly.

## Risk note

`gc.sh` keeps the 3 newest system generations, the profile's current generation, and any generation that is booted (`/run/booted-system`) or running (`/run/current-system`), and deletes the rest. After running this, rolling back via the bootloader will not be possible for the deleted generations. Keeping the booted generation is a guarantee of the list logic in `gc-preview.sh --delete-list`, not a property of the profile: a rollback can make the current generation an older one, and that is why the current generation is kept explicitly.

## Scripts

```
/home/bosko/NixOS/.claude/skills/nixos-gc/scripts/gc-preview.sh               # unprivileged — safe to run automatically; `--delete-list` prints the delete list
/home/bosko/NixOS/.claude/skills/nixos-gc/scripts/gc.sh                        # privileged (sudo) — hand off to the user, never run directly
/home/bosko/NixOS/.claude/skills/nixos-gc/tests/test-gc.sh                     # tests on fake profiles and stubbed sudo/nix-env/nix-store
```
