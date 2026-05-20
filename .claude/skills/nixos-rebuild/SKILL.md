---
name: nixos-rebuild
description: This skill should be used when the user wants to "rebuild nixos", "apply config", "stage rebuild", "boot with changes", "run nh os boot", or "rebuild and stage". It stages a NixOS system rebuild for next boot — it does NOT reboot automatically.
version: 0.1.0
---

# NixOS Rebuild (Stage for Next Boot)

Stage a NixOS system rebuild so that the new configuration becomes active on next boot. This is a HIGH-RISK operation — it modifies the system's boot configuration. Always show the user a dry-run diff and require explicit confirmation before proceeding.

## Instructions

### Step 1 — Dry-run first (mandatory)

Before doing anything else, run `scripts/dry-run.sh` (or invoke the `nixos-dry-run` skill). Show the full diff output to the user. Do not skip this step even if the user says "just rebuild" — it is a safety requirement.

### Step 2 — Confirm with the user

After showing the dry-run output, ask the user:

> "The dry-run output is shown above. Type **YES** to stage the rebuild for next boot, or anything else to cancel."

Wait for the response. If the user types anything other than exactly `YES` (case-sensitive), abort and do not run the rebuild script.

### Step 3 — Run the rebuild

If the user confirmed with `YES`, run `scripts/rebuild.sh`. Stream the output so the user can see progress in real time.

### Step 4 — Post-rebuild message

After a successful rebuild, tell the user:
- The new configuration has been staged as the default boot entry.
- They need to **reboot** to activate the changes (`sudo reboot` or a normal system restart).
- Nothing has changed on the running system yet.

If the rebuild script exits with a non-zero code, show the full error output and do NOT suggest rebooting.

## Risk note

This operation writes to the Nix store and updates the bootloader. It does not reboot automatically. The running system is unaffected until the user reboots.

## Scripts

```
scripts/dry-run.sh   — preview (always run first)
scripts/rebuild.sh   — stage the rebuild (run only after YES confirmation)
```
