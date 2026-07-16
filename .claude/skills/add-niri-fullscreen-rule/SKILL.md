---
name: add-niri-fullscreen-rule
description: Triggers when user says "add a niri fullscreen rule", "make X open maximized", "have X launch fullscreen", "open X full screen by default", or "maximize X on open". Adds open-maximized true (the Mod+F / maximize-column equivalent) to an app's window-rule in the shared niri config, so the app always opens maximized.
---

# Add Niri Fullscreen Rule

Make an app always open maximized (equivalent to pressing Mod+F on it) by adding `open-maximized true` to its window-rule in `dotfiles/common/configs/niri-config.kdl`. (Bucket: Utility)

This is a sibling of `add-niri-window-rule`: that skill pins an app to a monitor/workspace (`open-on-workspace`/`open-on-output`); this skill only ever sets `open-maximized true`, reusing an app's existing window-rule block if one exists rather than creating a duplicate.

## Arguments

Parse from the user's request:

- **App** (required) — the application to maximize, e.g. `Kitty`, `Vesktop`, `Zen Browser`.

## Step 1 — Verify live, don't guess

```bash
niri msg windows    # confirms the real App ID of a running instance of the target app
```

If the app isn't currently running, fall back to its known app-id: check existing `window-rule` blocks in `dotfiles/common/configs/niri-config.kdl` for the convention already used, or check the flatpak ID in `modules/desktop-apps.nix` / the host's `environment.nix` for flatpak apps.

**Gotcha — one app-id can mean multiple windows:** X11 apps running under xwayland-satellite (e.g. Steam) can have several distinct windows sharing one app-id — Steam's main window, friends list, and chat windows are all app-id `steam`. One rule maximizes all of them together, which is usually fine. But games **launched from** Steam are separate X11 clients with their own distinct app-id/WM_CLASS each — there's no single wildcard rule that catches "any Steam game," and most games manage their own fullscreen state independently of the compositor anyway. Don't try to use this skill to blanket-cover per-game windows; if a specific game needs it, that's a one-off rule once you know that game's own app-id.

## Step 2 — Find or draft the window-rule block

```bash
grep -n 'match app-id' -A3 /home/bosko/NixOS/dotfiles/common/configs/niri-config.kdl
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

## Step 5 — Flag cross-host caveats

`niri-config.kdl` is shared across every niri host (currently `gaming` and `laptop`). If the target app is gaming-only (check `modules/gaming.nix` vs the shared `modules/desktop-apps.nix`), say so — the rule will silently no-op on laptop.

**If the app doesn't seem to pick up the rule after rebuild**, check whether it has its own login autostart entry (an app-level "run at login" preference that writes a `.desktop` file to `~/.config/autostart/`, picked up by `systemd-xdg-autostart-generator`) and is single-instance. If so, the autostart-created window is created before this rule can act on it, and re-launching the app just raises that already-existing (unmaximized) window instead of creating a fresh one the rule can catch. Fixing that requires disabling the app's own autostart preference, not a window-rule change — flag it to the user rather than trying to fix it as part of this skill.

## Step 6 — Remind the user of next steps

`niri-config.kdl` is Home-Manager-managed via a nix-store symlink — this repo's normal workflow is `nh os boot` (stages for the *next* boot), so the change only takes effect after a reboot; there's no live `nh os switch` in the normal flow here. Tell the user to run `/git-commit` when ready. Do not stage or commit automatically — that's the user's explicit action.
