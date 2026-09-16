# Wayland Screenshot — Gotchas

Load this if the screenshot doesn't reflect an env/theme change, or you're tempted to run this over SSH against another host.

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
