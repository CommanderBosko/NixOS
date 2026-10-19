---
name: add-niri-fullscreen-rule
description: Triggers when user says "add a niri fullscreen rule", "make X open maximized", "have X launch fullscreen", "open X full screen by default", "maximize X on open", "open X without focus", "open X unfocused", or "don't focus X on open". Adds open-maximized true (the Mod+F / maximize-column equivalent) and/or open-focused false (open without taking focus) to an app's window-rule in the target host's per-host niri overlay, reusing the app's existing window-rule block when one exists.
model: haiku
---

# Add Niri Fullscreen Rule

Set how an app opens by adding properties to its window-rule in the target host's per-host niri overlay, `hosts/<host>/niri-overlay.kdl`. Two properties are supported, alone or together:

- **maximize** — `open-maximized true` (the Mod+F / maximize-column equivalent): the app always opens maximized.
- **unfocused** — `open-focused false`: the app opens without taking keyboard focus, so a launch from a bind doesn't yank the monitor/workspace over to it.

Gaming's overlay already pairs the two in the same blocks (Vesktop, Deezer, qBittorrent), so setting both on one app is the common case for "launch it in the background, maximized". (Bucket: Utility)

This is a sibling of `add-niri-window-rule`: that skill pins an app to a monitor/workspace (`open-on-workspace`/`open-on-output`); this skill only sets `open-maximized` and/or `open-focused`, reusing an app's existing window-rule block if one exists rather than creating a duplicate.

Since 2026-07-17, per-app `window-rule` blocks live in a per-host overlay file; the shared `dotfiles/common/configs/niri-config.kdl` keeps only host-agnostic rules (e.g. Firefox PiP floating, kitty `open-focused false`), which apply to every niri host. Check the overlay files live (`wc -c hosts/*/niri-overlay.kdl`) to see which hosts actually have window-rule content.

## Arguments

Parse from the user's request:

- **App** (required) — the application to change, e.g. `Kitty`, `Vesktop`, `Zen Browser`.
- **Properties** (required) — which of `maximize` / `unfocused` to set. "maximized", "fullscreen", "full screen" → maximize; "without focus", "unfocused", "don't focus", "don't steal focus" → unfocused; both phrases → both. If it's genuinely unclear, ask via the **AskUserQuestion** tool with options `maximize`, `unfocused`, `both`.
- **Host** (optional, default `gaming`) — which host's overlay to edit. If the user didn't name one, present the pick via the **AskUserQuestion tool** with one option per desktop host (`"desktop": true` in `.claude/hosts.json`), `gaming` first as the default; skip the question if the user already supplied the host.

## Step 1 — Verify live, don't guess

```bash
niri msg windows    # confirms the real App ID of a running instance of the target app
```

If the app isn't currently running, fall back to its known app-id: check existing `window-rule` blocks in `hosts/<host>/niri-overlay.kdl` for the convention already used, or check the flatpak ID in `modules/flatpak.nix` / the host's `environment.nix` for flatpak apps.

**Gotcha — one app-id can mean multiple windows:** a rule applies to every window sharing the app-id (e.g. all of Steam's windows), and games launched from Steam each have their own app-id — don't try to blanket-cover per-game windows. Details in `references/edge-cases.md`.

## Step 2 — Find or draft the window-rule block

```bash
grep -n 'match app-id' -A4 /home/bosko/NixOS/hosts/<host>/niri-overlay.kdl
```

- If a `window-rule` block for this app-id already exists, add each requested property as a new line inside that same block — don't create a duplicate block. Skip any property already present with the same value. If it's present with a different value (e.g. `open-focused true`), show it and confirm the change in Step 3.
- If no block exists yet, draft a new one, matching the file's existing regex-anchoring style (`^...$`, dots escaped as `\.`), with only the requested properties:
  ```kdl
  window-rule {
      match app-id=r#"^<escaped-app-id>$"#
      open-focused false
      open-maximized true
  }
  ```
- Property order inside a block doesn't matter to niri; follow the existing block's order when editing one.
- If the shared `niri-config.kdl` also has a rule for this app-id (e.g. kitty's `open-focused false`), leave it alone. Overlay rules are included after the shared window-rules, so the overlay's properties apply on top.

## Step 3 — Confirm before writing

Show the user the exact new/changed block and confirm via the **AskUserQuestion** tool, with one option `Confirm` (write it) and one option `Cancel` (make no change) — matching `add-niri-window-rule`'s and `add-niri-keybind`'s confirm gate. Do not write anything until the user selects `Confirm`.

## Step 4 — Verify

Run the `nixos-dry-run` skill to confirm the config still evaluates cleanly after the edit.

## Step 5 — Flag app-availability and behaviour caveats

Since the rule is written into the target host's own overlay file, there's no cross-host leakage to worry about. Still worth checking: is the target app installed on that host? Check `modules/gaming.nix` (gaming-only packages) vs the shared `modules/desktop-apps.nix` (packages) / `modules/flatpak.nix` (flatpaks) vs the host's own `environment.nix` — if it's not installed there, say so.

For `unfocused`, tell the user the window will not take focus on open, so they have to click or focus it themselves after launch.

**If the app doesn't seem to pick up the rule after rebuild**, check for a single-instance app with its own login autostart entry — flag it to the user (the fix is disabling the app's autostart preference, not a window-rule change); see `references/edge-cases.md`.

## Step 6 — Remind the user of next steps

The per-host overlay file is Home-Manager-managed via a nix-store symlink, same as `niri-config.kdl` — this repo's normal workflow is `nh os boot` (stages for the *next* boot), so the change only takes effect after a reboot; there's no live `nh os switch` in the normal flow here. Remind them:

> 1. Rebuild (`rebuild-boot`) and reboot to activate the rule.
> 2. After rebooting, run `/wayland-screenshot <app>` to confirm the app opens as intended (maximized and/or without taking focus).
> 3. Commit the change: `/git-commit`

Do not stage or commit automatically — that's the user's explicit action.
