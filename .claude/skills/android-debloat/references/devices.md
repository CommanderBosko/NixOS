# Android Debloat — Devices done so far

One screen per device, from the 2026-10-28 runs. Full detail lives in `reference_tv_debloat_tools_research.md` and `reference_galaxy_tab_a7_debloat_research.md` (project memory). Add a block here when a new device teaches something.

| Device | Tailnet name | Platform | List / tool used | Disabled | Tailscale at boot |
|---|---|---|---|---|---|
| TCL "Smart TV Pro" (G08) | `living-room-tv` | Google TV, Android 14 | CleanYourTV `examples/tcl-g08-us-google-tv/` plus its launcher, built from source with the nix androidenv SDK | 33 | No (`TclAppBoot`); open the app after power-on |
| Natalie's Fire TV Stick (AFTSS) | `natalies-firetvstick` | Fire OS 7.7.1.7, Android 9 | DumbTV `data/fireos/` lists and launcher; DNS filter skipped | 42 | Yes, via always-on VPN |
| Samsung Galaxy Tab A7 (SM-T500, Wi-Fi) | `kurts-galaxy-tab-a7` | Android 12, EOL since mid-2024 | Generic Samsung lists (khlam, Willie169, SamFlux) cross-checked; UAD-ng is the best tool | 27 | Yes, via always-on VPN |

## Which list source

- **Google TV:** CleanYourTV (`github.com/Gathin23/cleanyourtv`, per-model lists in `examples/`). DumbTV's Android TV support is thin.
- **Fire OS:** DumbTV (`github.com/humblemuzzu/dumbtv`, `data/fireos/`).
- **Samsung phone or tablet:** Universal Android Debloater Next Generation, or a Samsung list; every list is generic, none verified on the exact model. Confirm each name against the device's `pm list packages`.
- **Anything else:** run the `research` skill first; do not assume a TV tool fits a tablet.

## Per-device notes worth carrying over

- Ask first what the device is used for. The TV keeps Disney+, Hulu, HBO Max, Prime Video, Netflix, YouTube, Jellyfin, Tailscale and more; the tablet is a kitchen screen for Jellyfin and Famdash in Chrome, with Netflix kept.
- Jellyfin on a client stays on gaming's tailnet address `100.66.15.1:8096`, so a TV whose Tailscale does not auto-start needs the app opened after each power-on.
- Not done and left to the user: hand-testing remote buttons, Jellyfin playback, Famdash in Chrome; optional further removals only when the user names them.
