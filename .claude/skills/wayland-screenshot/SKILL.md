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

- **Don't rely on `QT_DEBUG_PLUGINS`/stderr debug tracing for Qt/KDE apps launched this way** —
  on this system, GUI apps launched via `nohup ... &` produced no captured debug output at all
  even with correct redirection and `QT_LOGGING_RULES` set (observed with `dolphin`), regardless
  of whether the app actually loaded the plugin in question. Screenshot-based visual verification
  is the reliable fallback when plugin-loading logs don't materialize.
- **A live session's `systemd --user` environment doesn't refresh on `nixos-rebuild switch`.**
  `/etc/set-environment` gets the new values, but a `systemd --user` session that started before
  the switch keeps its old environment until the next login. If an app launched from a login-shell
  process doesn't reflect a just-switched env change, push it into the running session with
  `systemctl --user set-environment <VAR>="<value>"` before relaunching, rather than concluding the
  rebuild failed.
- **`/etc/set-environment` itself references unset variables** (e.g. `XDG_STATE_HOME`) — sourcing
  it under `set -u` errors out. `capture.sh` already disables `set -u` around the `source` call;
  keep that if editing the script.
- **This skill only works on the machine Claude Code is running on.** `capture.sh` needs a live
  local Wayland/niri session and a hardcoded local script path; running it via
  `ssh <host> '.../capture.sh ...'` against a *different* host fails with `failed to create
  display` even when that host's desktop session is genuinely up (observed against both `laptop`
  and `natalie-laptop` during a cross-host theme check). For cross-host visual verification, run
  this skill locally on the host in question (or ask the user to check that host's desktop
  directly) — don't retry it over SSH.
