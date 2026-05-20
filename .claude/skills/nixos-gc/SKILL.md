---
name: nixos-gc
description: This skill should be used when the user wants to "garbage collect", "clean up nix store", "free disk space", "remove old generations", "run nix gc", or "cleanup nixos". It permanently removes old Nix store paths and system generations that are no longer referenced.
version: 0.1.0
---

# NixOS Garbage Collection

Remove unreferenced Nix store paths and old system generations to free disk space. This is a HIGH-RISK, IRREVERSIBLE operation — deleted generations cannot be restored.

## Instructions

### Step 1 — Warn the user (mandatory)

Before running anything, present this warning clearly:

> "Garbage collection will permanently delete old NixOS generations and unreferenced store paths. This cannot be undone. You will no longer be able to roll back to generations older than the 3 most recent."

### Step 2 — Confirm with the user

Ask:

> "Type **YES** to proceed with garbage collection, or anything else to cancel."

Wait for the response. If the user types anything other than exactly `YES` (case-sensitive), abort — do not run the script.

### Step 3 — Run garbage collection

If the user confirmed with `YES`, run `scripts/gc.sh`. This keeps the 3 most recent system generations, deletes older ones, then runs `sudo nix-store --gc` to free the actual store paths.

### Step 4 — Report results

After the script completes, parse its output and report:
- How many store paths were deleted (look for "X paths freed" or similar lines in nix output)
- How much disk space was freed (look for the MiB/GiB freed line)
- Confirm that the operation completed successfully

If the script exits with a non-zero code, show the full error output.

## Risk note

This script keeps the 3 most recent system generations and deletes the rest. After running this, rolling back via the bootloader will not be possible for any generation older than the 3 most recent. The currently-booted generation is always among the ones preserved.

## Script

```
scripts/gc.sh
```
