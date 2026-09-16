---
name: wayland-screenshot
description: Capture a screenshot of the live niri/Wayland desktop session — optionally after launching a specific app — to visually verify a DE/theming/GUI config change instead of inferring correctness from config alone. Use when the user says "screenshot the desktop", "screenshot niri", "show me what X looks like", "verify this visually", or "screenshot X app".
---

# Wayland Screenshot

Capture and view a screenshot of the live niri/Wayland session to verify a GUI, theming, or
desktop-environment change actually looks right — rather than trusting config alone. (Bucket:
Verification)

## Arguments

Parse from the user's request:

- **`<app>`** (optional) — a specific app to launch fresh and screenshot (e.g. "screenshot
  dolphin"). If omitted, capture the desktop as it currently is — don't launch anything.
- **`<env vars>`** (optional) — any `VAR=value` overrides the app needs for the check (e.g. a
  specific `QT_PLUGIN_PATH` while debugging a theming issue). Only relevant when `<app>` is given.

## Steps

1. **Resolve the output path.** Use the current session's scratchpad directory if one is set
   (see the "Scratchpad Directory" section of the system prompt); otherwise fall back to `/tmp`.
   Pick a short, descriptive filename, e.g. `<scratchpad>/dolphin_shot.png`.

2. **Capture:**
   ```bash
   /home/bosko/NixOS/.claude/skills/wayland-screenshot/scripts/capture.sh <output.png> [app] [env=val ...]
   ```
   With no `app`, it just screenshots the current desktop state. With an `app`, it refreshes the
   session environment (`/etc/set-environment` — a tool-invoked shell can inherit a stale
   environment from before a `nixos-rebuild switch`, which reads as "the fix didn't work" when it
   actually did), kills any already-running instance of that app from a prior verification pass,
   relaunches it detached with the given env overrides, waits for it to render, then captures.

3. **View it.** `Read` the resulting PNG with the Read tool and visually inspect it against what
   the change was supposed to do (e.g. dark vs. light theme, correct layout, expected window
   rules applied).

4. **Report back** what the screenshot shows in plain language, and whether it confirms the
   change worked. If it doesn't, say what's visibly wrong rather than re-asserting the config
   should have worked.

## Gotchas

Screenshot doesn't reflect an env/theme change, or tempted to run this over SSH against another host? Check `references/gotchas.md` for four known failure modes first.
