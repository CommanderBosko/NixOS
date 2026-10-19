---
name: add-niri-keybind
description: Triggers when user says "add a niri keybind", "bind Mod+X to...", "does Mod+X do anything", or "what's bound to Mod+X". Checks or adds a keybind following this repo's spawn/spawn-sh and window-rule conventions. Shared binds go in the shared niri config; a bind for an app installed on only one host goes into that host's hosts/<host>/niri-overlay.kdl binds block.
model: haiku
---

# Add Niri Keybind

Check what a key combo is currently bound to, and/or add a new keybind. Where the bind lands depends on which hosts have the app:

- **Shared bind** (app installed on every desktop niri host) → `dotfiles/common/configs/niri-config.kdl`, inside its `binds { }` block.
- **Host-only bind** (app installed on one host, e.g. Steam/Lutris on gaming) → `hosts/<host>/niri-overlay.kdl`, inside a `binds { }` block (created if missing). The shared config includes the overlay, and gaming's overlay already relies on its `binds` merging into the shared ones (Mod+G).

(Bucket: Utility)

For a standalone "always open X on monitor Y" request with **no keybind involved**, use `add-niri-window-rule` instead.

## Arguments

Parse from the user's request:

- **Key combo** (required) — the bind to check or add, e.g. `Mod+G`, `Mod+Shift+E`.
- **Action** (required if adding) — what the bind should do: a single command (with args), or multiple programs to launch together.

## Step 1 — Which hosts have the app (adding only)

Skip for a pure "does Mod+X do anything" query. Otherwise, run this before anything else:

1. Desktop hosts: the `"desktop": true` entries in `/home/bosko/NixOS/.claude/hosts.json` (currently gaming, laptop, natalie-laptop).
2. Where the app comes from:
   ```bash
   grep -rn -i "<package-name>" /home/bosko/NixOS/modules/ /home/bosko/NixOS/hosts/*/environment.nix
   ```
   - In `modules/gaming.nix` only (imported only by gaming in `flake.nix`) → **host-only** → overlay of that host.
   - In `modules/desktop-apps.nix` or `modules/flatpak.nix` (imported by all desktop hosts) → **shared**.
   - In one host's `environment.nix` only → **host-only** for that host.
3. If the answer is unclear (e.g. the app appears in several places, or nowhere), ask via the **AskUserQuestion** tool with options `Shared (all desktop hosts)`, one option per host, `Cancel`.

## Step 2 — Check what's already bound

Grep the shared config and every per-host overlay for the requested key combo and its Shift/Ctrl/Alt variants, e.g. for `Mod+G`:

```bash
grep -n "Mod+G\b\|Mod+Shift+G\|Mod+Ctrl+G\|Mod+Alt+G" /home/bosko/NixOS/dotfiles/common/configs/niri-config.kdl /home/bosko/NixOS/hosts/*/niri-overlay.kdl
```

Report what's found. If the user only asked "does Mod+X do anything" / "what's bound to Mod+X", stop here — this answers the question, no edit needed.

**A key combo that is already bound, in either file, is a conflict.** Do not overwrite or add a second binding for it. Show the existing line and ask via the **AskUserQuestion** tool: replace the existing bind, pick a different combo (recommended), or cancel.

## Step 3 — If adding a new bind, pick the right action syntax

- **Single command, with or without args:** `spawn "cmd" "arg1" "arg2"` (each arg its own quoted string — no shell involved).
- **Multiple programs launched at once, or anything needing shell features (pipes, `&&`, `||`):** `spawn-sh "cmd1 & cmd2 &"` — background each program with a trailing `&` so niri's spawn doesn't block waiting on the first one to exit.

Use the block shape already in the target file. The overlay form (gaming's Mod+G is the model):

```kdl
binds {
    Mod+G hotkey-overlay-title="Launch Initial Setup: ..." { spawn-sh "steam & lutris &"; }
}
```

- **Shared file:** insert the new bind near related/similar existing binds inside the existing `binds { }` block.
- **Overlay file:** if `binds {` already exists there, add the line inside it. If it doesn't, append a new `binds { }` block at the end of the file, after any existing `window-rule` / `workspace` blocks, with a one-line comment saying why it's host-only.

Use `hotkey-overlay-title="..."` on binds meant to show up in the hotkey overlay.

Before writing, show the user the exact new bind line and target file, and confirm via the **AskUserQuestion tool**, with one option `Confirm` (write it) and one option `Cancel` (make no change) — matching the confirm gate `add-package`/`add-flatpak` use before their edits. Do not write anything until the user selects `Confirm`.

## Step 4 — If the bind involves a window rule (open-on-workspace / open-on-output)

Don't guess app-ids or output/connector names — verify against the live session first:

```bash
niri msg windows    # confirms real App ID: values for running apps
niri msg outputs    # confirms real connector names, e.g. DP-1, HDMI-A-1
```

Use those confirmed values in `match app-id=r#"^...$"#` and `open-on-output "..."` / `open-on-workspace "..."`. **The window-rule (and any new workspace block it needs) goes in the target host's per-host overlay, `hosts/<host>/niri-overlay.kdl`** (default `gaming`; if ambiguous, ask via the **AskUserQuestion tool** with one option per desktop host from `.claude/hosts.json`, `gaming` first) — not in the shared `niri-config.kdl`. See `add-niri-window-rule` for the overlay-file conventions (naming, placement) in detail.

## Step 5 — Flag cross-host caveats (shared binds only)

A shared bind is active on every niri host (the `"desktop": true` hosts in `.claude/hosts.json`). If its command targets an app that isn't installed on all of them, say so before finishing, using the Step 1 check. Example: a shared bind launching Steam/Lutris would silently no-op on laptop and natalie-laptop — that's why such binds go in gaming's overlay instead.

## Step 6 — Verify

Run the `nixos-dry-run` skill to confirm the config still evaluates cleanly after the edit.

## Step 7 — Remind the user of next steps

If Step 4 added a window-rule (the bind opens an app pinned to a specific output/workspace), remind the user that overlay file only takes effect after a reboot — there's no live `nh os switch` in the normal flow here:

> 1. Rebuild (`rebuild-boot`) and reboot to activate the rule.
> 2. After rebooting, run `/wayland-screenshot <app>` to confirm it opens on the intended output/workspace.
> 3. Commit the change: `/git-commit`

If no window-rule was involved (a plain keybind with nothing to screenshot), just tell the user to run `/git-commit` when ready. Do not stage or commit automatically — that's the user's explicit action.
