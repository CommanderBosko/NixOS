---
name: add-niri-fullscreen-rule
description: Triggers when user says "add a niri fullscreen rule", "make X open maximized", "have X launch fullscreen", "open X full screen by default", or "maximize X on open". Adds open-maximized true (the Mod+F / maximize-column equivalent) to an app's window-rule in the target host's per-host niri overlay, so the app always opens maximized.
model: haiku
---

# Add Niri Fullscreen Rule

Make an app always open maximized (equivalent to pressing Mod+F on it) by adding `open-maximized true` to its window-rule in the target host's per-host niri overlay, `hosts/<host>/niri-overlay.kdl`. (Bucket: Utility)

This is a sibling of `add-niri-window-rule`: that skill pins an app to a monitor/workspace (`open-on-workspace`/`open-on-output`); this skill only ever sets `open-maximized true`, reusing an app's existing window-rule block if one exists rather than creating a duplicate.

Since 2026-07-17, all app-id `window-rule` blocks live in a per-host overlay file, not the shared `dotfiles/common/configs/niri-config.kdl`. Only `gaming`'s overlay currently has real window-rule content.

## Arguments

Parse from the user's request:

- **App** (required) — the application to maximize, e.g. `Kitty`, `Vesktop`, `Zen Browser`.
- **Host** (optional, default `gaming`) — which host's overlay to edit. Default to `gaming` since it's the only host with real window-rule content today; ask if ambiguous.

## Step 1 — Verify live, don't guess

```bash
niri msg windows    # confirms the real App ID of a running instance of the target app
```

If the app isn't currently running, fall back to its known app-id: check existing `window-rule` blocks in `hosts/<host>/niri-overlay.kdl` for the convention already used, or check the flatpak ID in `modules/desktop-apps.nix` / the host's `environment.nix` for flatpak apps.

**Gotcha — one app-id can mean multiple windows:** X11 apps running under xwayland-satellite (e.g. Steam) can have several distinct windows sharing one app-id — Steam's main window, friends list, and chat windows are all app-id `steam`. One rule maximizes all of them together, which is usually fine. But games **launched from** Steam are separate X11 clients with their own distinct app-id/WM_CLASS each — there's no single wildcard rule that catches "any Steam game," and most games manage their own fullscreen state independently of the compositor anyway. Don't try to use this skill to blanket-cover per-game windows; if a specific game needs it, that's a one-off rule once you know that game's own app-id.

## Step 2 — Find or draft the window-rule block

```bash
grep -n 'match app-id' -A3 /home/bosko/NixOS/hosts/<host>/niri-overlay.kdl
```

- If a `window-rule` block for this app-id already exists (e.g. it already has `open-on-workspace`), add `open-maximized true` as a new line inside that same block — don't create a duplicate block.
- If no block exists yet, draft a new one, matching the file's existing regex-anchoring style (`^...$`, dots escaped as `\.`):
  ```kdl
  window-rule {
      match app-id=r#"^<escaped-app-id>$"#
      open-maximized true
  }
  ```

## Step 3 — Confirm before writing

Show the user the exact new/changed block and confirm via the **AskUserQuestion** tool, with one option `Confirm` (write it) and one option `Cancel` (make no change) — matching `add-niri-window-rule`'s and `add-niri-keybind`'s confirm gate. Do not write anything until the user selects `Confirm`.

## Step 4 — Verify

Run the `nixos-dry-run` skill to confirm the config still evaluates cleanly after the edit.

## Step 5 — Flag app-availability caveats

Since the rule is written into the target host's own overlay file, there's no cross-host leakage to worry about anymore. Still worth checking: is the target app installed on that host? Check `modules/gaming.nix` (gaming-only packages) vs the shared `modules/desktop-apps.nix` vs the host's own `environment.nix` — if it's not installed there, say so.

**If the app doesn't seem to pick up the rule after rebuild**, check whether it has its own login autostart entry (an app-level "run at login" preference that writes a `.desktop` file to `~/.config/autostart/`, picked up by `systemd-xdg-autostart-generator`) and is single-instance. If so, the autostart-created window is created before this rule can act on it, and re-launching the app just raises that already-existing (unmaximized) window instead of creating a fresh one the rule can catch. Fixing that requires disabling the app's own autostart preference, not a window-rule change — flag it to the user rather than trying to fix it as part of this skill.

## Step 6 — Remind the user of next steps

The per-host overlay file is Home-Manager-managed via a nix-store symlink, same as `niri-config.kdl` — this repo's normal workflow is `nh os boot` (stages for the *next* boot), so the change only takes effect after a reboot; there's no live `nh os switch` in the normal flow here. Remind them:

> 1. Rebuild (`rebuild`) and reboot to activate the rule.
> 2. After rebooting, run `/wayland-screenshot <app>` to confirm the app actually opens maximized.
> 3. Commit the change: `/git-commit`

Do not stage or commit automatically — that's the user's explicit action.
