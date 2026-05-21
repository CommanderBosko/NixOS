---
name: diff-generations
description: Use this skill when the user wants to "diff generations", "what changed after rebuild", "show generation diff", or "what packages changed". Shows what changed between the current NixOS generation and the previous one.
version: 0.1.0
---

# Diff NixOS Generations

Show what changed between the current active NixOS generation and the previous one by comparing store closures.

## Step 1 — Check that both profiles exist

Run in parallel:

```bash
ls -la /run/current-system
ls -la /nix/var/nix/profiles/system
```

If either path is missing or unreadable, report the error and stop. Both must exist for the diff to work.

## Step 2 — Run the closure diff

```bash
nix store diff-closures /nix/var/nix/profiles/system-1-link /run/current-system
```

> Note: `/nix/var/nix/profiles/system` is a symlink to the *current* generation. To compare current vs previous, use `system-1-link` (one step back) vs `/run/current-system`. If `system-1-link` doesn't exist (first generation), explain that there is no previous generation to compare against.

If `system-1-link` is not present, try this fallback to list available generations:

```bash
ls -1v /nix/var/nix/profiles/ | grep '^system-'
```

Then pick the highest-numbered `system-N-link` as "previous" and diff against `/run/current-system`.

## Step 3 — Present the output

Parse and summarise the diff output:

- **Added packages** — lines showing a new version with no previous version (e.g. `foo: ∅ → 1.0`)
- **Removed packages** — lines showing a version dropped to nothing (e.g. `foo: 1.0 → ∅`)
- **Updated packages** — lines showing a version change (e.g. `foo: 1.0 → 1.1`)
- **Unchanged** — omit from the summary unless the user asks for the full list

Format the summary as three sections:

```
Added (N):
  package-name  1.0

Removed (N):
  package-name  1.0

Updated (N):
  package-name  1.0 → 1.1
```

If there are no changes in a category, omit that section entirely.

Print the **full raw diff first**, then the summary below it so the user has both views.

## Step 4 — Note kernel/initrd changes

If any of the changed packages contain `linux-`, `kernel`, or `initrd` in their name, add a note:

> Kernel or initrd changed — a reboot is required to activate these changes.

---

## Key facts

- Working directory: `/home/bosko/NixOS`
- This is a read-only operation — safe to run at any time.
- `nix store diff-closures` requires the Nix store paths to be valid; they always are for active generations.
- The "current" generation is `/run/current-system`; previous generations are at `/nix/var/nix/profiles/system-N-link`.
