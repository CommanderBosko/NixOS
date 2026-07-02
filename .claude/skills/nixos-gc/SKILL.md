---
name: nixos-gc
description: This skill should be used when the user wants to "garbage collect", "clean up nix store", "free disk space", "remove old generations", "run nix gc", or "cleanup nixos". It permanently removes old Nix store paths and system generations that are no longer referenced.
version: 0.1.0
---

# NixOS Garbage Collection

Remove unreferenced Nix store paths and old system generations to free disk space. This is a HIGH-RISK, IRREVERSIBLE operation — deleted generations cannot be restored.

## Arguments

None. This skill takes no invocation-time inputs — it always keeps the 3 most recent generations and collects the rest.

## Instructions

### Step 1 — Warn the user (mandatory)

Before running anything, present this warning clearly:

> "Garbage collection will permanently delete old NixOS generations and unreferenced store paths. This cannot be undone. You will no longer be able to roll back to generations older than the 3 most recent."

### Step 2 — Confirm with the user

Present the destructive confirmation as a hard gate via the **AskUserQuestion tool**, with exactly two options: **Proceed** (run garbage collection) and **Cancel** (abort, do nothing). Do not use free-form prose or a typed-`YES` match for this gate. This gate is mandatory even if the user's original phrasing sounded like a go-ahead — always require an explicit pick here because the operation is irreversible.

Wait for the response. If the user picks anything other than **Proceed**, abort — do not run the script.

### Step 3 — Preview what would be deleted (unprivileged, safe to run automatically)

Run `scripts/gc-preview.sh` and show the user its output. It reads generation info directly from
`/nix/var/nix/profiles/system-*-link` symlinks — no sudo required — so it's safe to run without
hand-off, and gives an accurate preview of exactly which generations would be removed before
anything privileged happens.

### Step 4 — Hand off the actual deletion to the user

`scripts/gc.sh` (the destructive script) calls `sudo nix-env --list-generations`, `sudo nix-env
--delete-generations`, and `sudo nix-store --gc`. There is no NOPASSWD rule for `sudo` on any host,
so running `scripts/gc.sh` directly via the Bash tool will fail with "a password is required" —
don't attempt it and then report the failure. Instead, tell the user the exact command
(`scripts/gc.sh`, or its full path) and ask them to run it themselves (suggest the `!` prefix).

### Step 5 — Report results

Once the user confirms it ran, re-run `scripts/gc-preview.sh` to confirm the old generations are
actually gone (its output will show only the 3 kept generations remaining). Ask the user for the
disk-space-freed line from their own terminal output, since Claude never sees it directly.

## Risk note

`gc.sh` keeps the 3 most recent system generations and deletes the rest. After running this, rolling back via the bootloader will not be possible for any generation older than the 3 most recent. The currently-booted generation is always among the ones preserved.

## Scripts

```
scripts/gc-preview.sh   # unprivileged — safe to run automatically, preview only
scripts/gc.sh           # privileged (sudo) — hand off to the user, never run directly
```
