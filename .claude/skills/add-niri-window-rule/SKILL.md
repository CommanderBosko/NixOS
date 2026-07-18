---
name: add-niri-window-rule
description: Triggers when user says "add a niri window rule", "pin X to the Dell/Asus monitor", "open X on desktop N", "always open X on monitor Y", or "add a window rule for X". Pins an app to a specific monitor/workspace slot via a standalone niri window-rule in the target host's per-host niri overlay, with no keybind involved.
model: haiku
---

# Add Niri Window Rule

Pin an app to a specific monitor via a niri window-rule (`open-on-workspace`/`open-on-output`) in a host's per-host niri overlay `hosts/<host>/niri-overlay.kdl`, creating a new named workspace slot if one doesn't already exist on the target output. (Bucket: Utility)

This is the sibling of `add-niri-keybind`: that skill handles binds plus any window-rule that rides along with a *new keybind*; this skill handles a standalone "always open X on monitor Y" request with no keybind involved.

Since 2026-07-17, workspaces/window-rules live in a **per-host overlay** file (`hosts/<host>/niri-overlay.kdl`), pulled into the shared `dotfiles/common/configs/niri-config.kdl` via a native niri `include "niri-overlay.kdl"` directive — not in the shared file itself. This means a rule added here is automatically scoped to just the target host; there's no cross-host leakage to worry about the way there was before that split. Only `gaming`'s overlay currently has real content (its two-monitor Asus+Dell setup); `laptop`'s and `natalie-laptop`'s overlays are empty placeholders.

## Arguments

Parse from the user's request:

- **App** (required) — the application to pin, e.g. `Deezer`, `Discord`.
- **Target monitor** (required) — which physical monitor/output the app should always open on, e.g. "Dell monitor", "Asus monitor".
- **Host** (optional, default `gaming`) — which host's overlay to edit. Default to `gaming` since it's the only host with a real multi-monitor setup today; ask if ambiguous.

## Step 1 — Verify live, don't guess

```bash
niri msg outputs    # confirms real connector names, e.g. DP-1, HDMI-A-1
niri msg windows    # confirms the real App ID: of a running instance of the target app
```

If the app isn't currently running, fall back to its known app-id (e.g. a flatpak app's niri app-id typically equals its flatpak ID verbatim — check `modules/desktop-apps.nix` or the host's `environment.nix` for the flatpak ID if needed).

## Step 2 — Find or choose a workspace slot

Grep the target host's overlay file for existing named-workspace blocks pinned to an output:

```bash
grep -n 'workspace ".*" {' -A1 /home/bosko/NixOS/hosts/<host>/niri-overlay.kdl
```

- If a workspace already pinned to the target output has no window-rule occupant yet, it can be reused.
- If every existing slot on that output already has an app pinned to it via a `window-rule`, tell the user and ask (via **AskUserQuestion**) whether to add a new slot or reassign an existing one — don't silently double-book a slot.
- If a new slot is needed, follow the file's existing monitor-slot naming convention (`asus-1`, `asus-2`, `asus-3`, `dell-1`, `dell-2`, `dell-3`, ...) — pick the next unused number for that monitor's prefix.

## Step 3 — Draft the new block(s)

- If a new workspace slot is needed, add:
  ```kdl
  workspace "<name>" {
      open-on-output "<connector>"
  }
  ```
  near the existing named-workspace block.
- Add the window-rule:
  ```kdl
  window-rule {
      match app-id=r#"^<escaped-app-id>$"#
      open-on-workspace "<name>"
  }
  ```
  near the existing per-app window-rules, matching the file's regex-anchoring style (`^...$`, dots escaped as `\.`).

## Step 4 — Confirm before writing

Show the user the exact new block(s) and confirm via the **AskUserQuestion** tool, with one option `Confirm` (write it) and one option `Cancel` (make no change) — matching `add-niri-keybind`'s and `add-package`'s confirm gate. Do not write anything until the user selects `Confirm`.

## Step 5 — Flag app-availability caveats

Since the rule is written into the target host's own overlay file, there's no cross-host leakage risk to flag anymore. Still worth checking: is the target app actually installed on that host? Check `modules/gaming.nix` (gaming-only packages) vs `modules/desktop-apps.nix` (shared across all desktop hosts) vs the host's own `environment.nix`. If the app isn't installed on the target host, the rule will just never match anything there — say so before finishing.

## Step 6 — Verify

Run the `nixos-dry-run` skill to confirm the config still evaluates cleanly after the edit.

## Step 7 — Remind the user of next steps

Tell the user to run `/git-commit` when ready. Do not stage or commit automatically — that's the user's explicit action.
