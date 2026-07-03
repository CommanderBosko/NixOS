---
name: switch-de
description: Triggers when user says "switch desktop environment", "change DE", "switch to X", "swap DE", "try X desktop", "change desktop on laptop/gaming", or "switch compositor". Swaps the DE import line in flake.nix for a given desktop host.
version: 0.2.0
---

# Switch Desktop Environment

Swap the active desktop environment module for a desktop host by editing the DE import line in `flake.nix`. Follow every step in order. Do not edit `flake.nix` until the user confirms.

## Arguments

Parse from the user's request:

- **`<host>`** (optional) — one of the **desktop hosts** (the hosts with `"desktop": true` in `.claude/hosts.json` — currently `gaming`, `laptop`, `natalie-laptop`). If omitted, ask in Step 1.
- **`<target-de>`** (optional) — the desktop environment module to switch to, e.g. `niri`, `plasma`, `cosmic`. Must match a module under `dotfiles/common/modules/desktop-environments/`. If omitted, ask in Step 1.

## Step 1 — Gather information

If the user has not already provided both pieces of information, ask them in a single message:

1. **Host** — Which host to switch? Valid desktop hosts are those with `"desktop": true` in `.claude/hosts.json` (currently `gaming`, `laptop`, `natalie-laptop`). If the user did not already name a host, present this pick via the **AskUserQuestion tool** with one option per desktop host rather than free-form prose; skip the question if the user already supplied the host. (Headless hosts like `vpn-server` have no DE — reject them with a clear explanation.)

2. **Target DE** — Which desktop environment to switch to?

List the available DE modules so the user can choose. Enumerate them **live** so the list can never go stale:

```bash
ls /home/bosko/NixOS/dotfiles/common/modules/desktop-environments/*.nix | xargs -n1 basename | sed 's/.nix$//'
```

These are the files in `dotfiles/common/modules/desktop-environments/`. If the user did not already name a target DE, present this pick via the **AskUserQuestion tool**, populating its options from the live enumeration above (one option per available DE module) rather than free-form prose; skip the question if the user already supplied the target DE.

Do not proceed to Step 2 until you have both answers.

## Step 2 — Verify the target module exists

Check whether `dotfiles/common/modules/desktop-environments/<target>.nix` exists:

```bash
ls /home/bosko/NixOS/dotfiles/common/modules/desktop-environments/<target>.nix
```

If the file does not exist, stop and tell the user:

> The module `<target>.nix` does not exist yet. Use `/new-module` to scaffold it first, then come back to `/switch-de`.

Do not proceed until the target module file exists.

## Step 3 — Show current and proposed state

Read `/home/bosko/NixOS/flake.nix` and locate the DE import line for the requested host. Each desktop host has exactly one line matching this pattern inside its `modules` list:

```
"${self}/dotfiles/common/modules/desktop-environments/<current>.nix"
```

Present both lines clearly:

```
Host:     <host>

Current:  "${self}/dotfiles/common/modules/desktop-environments/<current>.nix"
Proposed: "${self}/dotfiles/common/modules/desktop-environments/<target>.nix"
```

If you cannot find a DE import line for the host, explain what you see and ask the user to verify.

## Step 4 — SDDM / displayManager warning (conditional)

If the host's `environment.nix` sets `services.displayManager.defaultSession`, warn the user:

> The target DE may need a different `services.displayManager.defaultSession` value in `hosts/<host>/environment.nix`. If the rebuild fails or SDDM loops, check and update that option to match the new DE's session name. You can also temporarily comment it out to let SDDM auto-detect.

Always emit this note when switching:
- **away from** `niri` or `hyprland` (Wayland-only compositors with no canonical session string)
- **to** `niri` or `hyprland`
- or when the old and new DEs belong to different display-server families (X11 ↔ Wayland)

If neither DE crosses that boundary, you may omit the note.

## Step 5 — Confirm before editing

Ask the user to confirm via the **AskUserQuestion tool**, with one option `Proceed` (update `flake.nix`) and one option `Cancel` (make no change). Do not touch any file until the user selects `Proceed`. If they select `Cancel`, stop and make no edit.

## Step 6 — Edit flake.nix

Using the Edit tool, replace **only** the DE import line for the target host. Do not touch any other part of `flake.nix`.

The old string to match (replace `<current>` with the actual module name found in Step 3):

```
"${self}/dotfiles/common/modules/desktop-environments/<current>.nix"
```

The new string (replace `<target>` with the chosen module name):

```
"${self}/dotfiles/common/modules/desktop-environments/<target>.nix"
```

Use the Edit tool's exact-string replacement. If the old string is not unique in the file (unlikely but possible), include enough surrounding lines to make it unique.

## Step 7 — Confirm the edit and next steps

After the edit succeeds, show the user the updated line in context (the two lines above and below it) so they can verify the change landed in the right place.

Then remind them of the next steps:

> 1. Preview the change: `/nixos-dry-run`
> 2. If the dry-run looks good, run `rebuild` in your terminal to apply (requires TTY/sudo)
> 3. Commit the change: `/commit`

---

## Key constraints

- **Only desktop hosts** — those with `"desktop": true` in `.claude/hosts.json` (currently `gaming`, `laptop`, `natalie-laptop`). Reject headless hosts (`vpn-server`).
- **One line changed** — only the DE import line for the target host. Nothing else.
- **Confirm before editing** — never edit `flake.nix` without explicit user approval.
- **Do not stage or commit** — that is the `/git-commit` skill's job.
- **Do not reboot** — rebuilds are staged; the user reboots manually.
- **Target must exist** — if the `.nix` file is missing, stop and redirect to `/new-module`.

---

## Current DE assignments (as of flake.nix)

| Host           | Current DE module |
|----------------|-------------------|
| gaming         | plasma.nix        |
| laptop         | niri.nix          |
| natalie-laptop | plasma.nix        |

These are the defaults at the time this skill was written. Always read `flake.nix` live — don't rely on this table if it may have been changed since.
