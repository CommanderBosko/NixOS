# add-niri-fullscreen-rule — edge cases

Detail behind the one-line rules in SKILL.md Steps 1 and 5.

## One app-id can mean multiple windows (Step 1)

X11 apps running under xwayland-satellite (e.g. Steam) can have several distinct windows sharing
one app-id — Steam's main window, friends list, and chat windows are all app-id `steam`. One rule
maximizes all of them together, which is usually fine. But games **launched from** Steam are
separate X11 clients with their own distinct app-id/WM_CLASS each — there's no single wildcard
rule that catches "any Steam game," and most games manage their own fullscreen state
independently of the compositor anyway. Don't try to use this skill to blanket-cover per-game
windows; if a specific game needs it, that's a one-off rule once you know that game's own app-id.

## App doesn't pick up the rule after rebuild (Step 5)

Check whether the app has its own login autostart entry (an app-level "run at login" preference
that writes a `.desktop` file to `~/.config/autostart/`, picked up by
`systemd-xdg-autostart-generator`) and is single-instance. If so, the autostart-created window is
created before this rule can act on it, and re-launching the app just raises that
already-existing (unmaximized) window instead of creating a fresh one the rule can catch. Fixing
that requires disabling the app's own autostart preference, not a window-rule change — flag it to
the user rather than trying to fix it as part of this skill.
