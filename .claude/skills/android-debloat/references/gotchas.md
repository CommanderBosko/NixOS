# Android Debloat — Gotchas

Everything here was learned on the real devices on 2026-10-28 (sources: `reference_tv_debloat_tools_research.md`, `reference_galaxy_tab_a7_debloat_research.md`). Load it before connecting to an Android 11+ device and before touching a TV launcher.

## Connecting

- **Wireless debugging has three ports, not one.** The Android 11+ screen shows a random *pairing* port (single use) and, on the main Wireless debugging screen, a different random *connect* port. Neither is 5555 and both change after every reboot or re-pair. Any `adb connect` to the pairing port burns the code, and the next `adb pair` then fails with `protocol fault (couldn't read status message)`. About seven pair attempts failed on the Tab A7. This host's adb 37.0.0 has no mDNS, so nothing is discovered automatically.
- **USB debugging with a cable is the fast route** for a phone or tablet: `adb devices` showed it authorized at once. Use it as soon as one pair attempt fails.
- **A pairing code typed into a command lands in the session transcript.** It is single-use and expires in minutes, so it is low risk, but prefer USB and never reuse a code.
- **TVs and Fire Sticks listen on 5555** once debugging is on, and show `unauthorized` until the user presses Allow on the screen.
- `adb kill-server` then reconnect fixes `offline` after the device's Wi-Fi bounces.
- Reach the device on its Tailscale IP. If Tailscale is down after a reboot, a LAN address works as a temporary fallback; say so rather than leaving it in a note (`feedback_use_tailscale_ips`).

## Disabling

- **Wait ~20 s after the last `pm disable-user`, and `sync`, before rebooting.** Rebooting sooner silently reverts the disables. Always re-check with `apply-batch.sh --verify` after the reboot.
- **Disable, never uninstall.** `pm disable-user --user 0 <pkg>` is undone with `pm enable <pkg>`. `pm uninstall -k --user 0` (what some Samsung lists use) is undone by `cmd package install-existing --user 0 <pkg>`, but keep to disable.
- **Snapshot `pm list packages -d` first.** The device may already have disabled packages (the Tab A7 had 18) and Play Store can re-enable updated Google apps after a reboot (Assistant, Maps, YouTube, Earth came back). That is not your change; re-disable them only if the user wants.
- **Small batches, riskiest last.** CleanYourTV's own guidance and the TV run both used about 8 per batch. Stop and undo on the first launcher crash.
- Community lists disagree. When sources conflict, keep the package (the Tab A7 kept `smartcapture`, `scloud` and `samsungpass`) and ask the user.

## TV launcher and setup wizard (Google TV)

- **Disable the setup wizard FIRST, then the stock launcher.** The stock launcher is priority 2, the wizard 1, the replacement 0. Disabling the launcher first leaves Home on `setupwraith/.RecoveryActivity`, a crash-loop risk.
- **Forget and re-join Wi-Fi before disabling the wizard**, so the saved networks belong to `com.android.tv.settings`; Android deletes the wizard's networks when it is disabled.
- A few China-market TCL sets refuse any custom launcher. The CleanYourTV launcher has no INTERNET permission and WRITE_SECURE_SETTINGS is not granted.
- Remote shortcut buttons: keycodes of 1000 or more are answered by the launcher only while on its Home screen; keycode 190 (YouTube) needs an accessibility helper that also drops key repeats, so the user chose to leave it off.
- Rollback: re-enable the stock launcher and wizard, then `cmd package set-home-activity` to the stock launcher.

## Fire OS

- **DumbTV is Fire-OS-native; CleanYourTV on Fire OS is debloat-only.** Never run DumbTV's `all.sh` or its DNS filter on a stick that needs Tailscale: the filter is a local VPN and Android runs one VPN at a time. Skip its OTA block and `lockdown.sh` as well (the Fire Stick kept OTA).
- A boot-time "Unable to Detect Your Remote" screen (`com.amazon.vizzini`) can appear after a reboot and clears on its own; if it sticks, do not disable vizzini.
- The launcher accessibility service plus `alarm_manager_constants min_futurity=0` is how DumbTV takes HOME. `launcher/install.sh --undo` removes it.

## Tailscale

- `cmd deviceidle whitelist +com.tailscale.ipn` plus `settings put secure always_on_vpn_app com.tailscale.ipn` (lockdown 0) makes Tailscale start at boot on Fire OS 7 and on the Tab A7 (back on the tailnet in about 40 s).
- It does not work on the TCL TV: `TclAppBoot` blocks `IPNService` and BOOT_COMPLETED and resets the AUTO_START appop each boot. Open the Tailscale app after every power-on, or run `adb shell am broadcast -a com.tailscale.ipn.CONNECT_VPN -n com.tailscale.ipn/.IPNReceiver`.

## Finishing

- Turn adb off at the end (`settings put global adb_enabled 0`); a factory reset would wipe the Tailscale and Jellyfin sign-ins.
- Each debloat is a dated reference memory (`Volatility: fast`): tool lists change weekly, so recheck the list source's date before reusing an old plan.
