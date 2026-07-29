---
name: add-niri-keybind
description: Triggers when user says "add a niri keybind", "bind Mod+X to...", "does Mod+X do anything", or "what's bound to Mod+X". Checks or adds a keybind in the shared niri config, following this repo's spawn/spawn-sh and window-rule conventions.
model: haiku
---

# Add Niri Keybind

Check what a key combo is currently bound to, and/or add a new keybind, in the shared niri config `dotfiles/common/configs/niri-config.kdl`. (Bucket: Utility)

For a standalone "always open X on monitor Y" request with **no keybind involved**, use `add-niri-window-rule` instead.

## Arguments

Parse from the user's request:

- **Key combo** (required) — the bind to check or add, e.g. `Mod+G`, `Mod+Shift+E`.
- **Action** (required if adding) — what the bind should do: a single command (with args), or multiple programs to launch together.

## Step 1 — Check what's already bound

Grep the file for the requested key combo and its Shift/Ctrl/Alt variants, e.g. for `Mod+G`:

```bash
grep -n "Mod+G\b\|Mod+Shift+G\|Mod+Ctrl+G\|Mod+Alt+G" /home/bosko/NixOS/dotfiles/common/configs/niri-config.kdl
```

Report what's found. If the user only asked "does Mod+X do anything" / "what's bound to Mod+X", stop here — this answers the question, no edit needed.

## Step 2 — If adding a new bind, pick the right action syntax

- **Single command, with or without args:** `spawn "cmd" "arg1" "arg2"` (each arg its own quoted string — no shell involved).
- **Multiple programs launched at once, or anything needing shell features (pipes, `&&`, `||`):** `spawn-sh "cmd1 & cmd2 &"` — background each program with a trailing `&` so niri's spawn doesn't block waiting on the first one to exit.

Insert the new bind near related/similar existing binds inside the `binds { }` block, matching the file's existing style (`hotkey-overlay-title="..."` on binds meant to show up in the hotkey overlay).

Before writing, show the user the exact new bind line and confirm via the **AskUserQuestion tool**, with one option `Confirm` (write it) and one option `Cancel` (make no change) — matching the confirm gate `add-package`/`add-flatpak` use before their edits. Do not write anything until the user selects `Confirm`.

## Step 3 — If the bind involves a window rule (open-on-workspace / open-on-output)

Don't guess app-ids or output/connector names — verify against the live session first:

```bash
niri msg windows    # confirms real App ID: values for running apps
niri msg outputs    # confirms real connector names, e.g. DP-1, HDMI-A-1
```

Use those confirmed values in `match app-id=r#"^...$"#` and `open-on-output "..."` / `open-on-workspace "..."`. **The window-rule (and any new workspace block it needs) goes in the target host's per-host overlay, `hosts/<host>/niri-overlay.kdl`** (default `gaming`, ask if ambiguous) — not in the shared `niri-config.kdl` the bind itself lives in. See `add-niri-window-rule` for the overlay-file conventions (naming, placement) in detail.

## Step 4 — Flag cross-host caveats

`niri-config.kdl` (binds) is shared across every niri host (`gaming`, `laptop`, and `natalie-laptop`). If the bind's command targets an app that isn't installed on all niri hosts, say so before finishing — check `modules/gaming.nix` (gaming-only packages) vs `modules/desktop-apps.nix` (shared across all desktop hosts) to tell which case applies. Example: a bind launching Steam/Lutris (gaming-only) will silently no-op on laptop and natalie-laptop.

## Step 5 — Verify

Run the `nixos-dry-run` skill to confirm the config still evaluates cleanly after the edit.

## Step 6 — Remind the user of next steps

If Step 3 added a window-rule (the bind opens an app pinned to a specific output/workspace), remind the user that overlay file only takes effect after a reboot — there's no live `nh os switch` in the normal flow here:

> 1. Rebuild (`rebuild`) and reboot to activate the rule.
> 2. After rebooting, run `/wayland-screenshot <app>` to confirm it opens on the intended output/workspace.
> 3. Commit the change: `/git-commit`

If no window-rule was involved (a plain keybind with nothing to screenshot), just tell the user to run `/git-commit` when ready. Do not stage or commit automatically — that's the user's explicit action.
