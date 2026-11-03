---
name: android-debloat
description: Debloat an Android device (Google TV, Fire TV Stick, Samsung tablet or phone) over adb on the tailnet by disabling packages in small verified batches, keeping Tailscale alive, and recording the outcome. Use when the user says "debloat the tv", "clean up the fire stick", "debloat the tablet", "remove bloatware from X", "adb debloat", or "do the same for the other device".
version: 0.1.0
---

# Android Debloat

Debloat one Android device the way the TCL TV, Natalie's Fire Stick and the kitchen Tab A7 were done on 2026-10-28: pick a community package list, subtract what the user keeps, disable the rest with `pm disable-user` in small batches, reboot and verify between batches, keep Tailscale running, turn adb off, save a memory note.

(Bucket: Utility. It changes a real device, so every batch is confirmed first. It only ever **disables** packages, which `pm enable` undoes: no `pm uninstall`, no factory reset, no root, no other `settings put` than the Tailscale keep-alive in Step 6.)

## Arguments

Parse from the user's request:

- **`device`** (required) — the tailnet name or a description ("living-room-tv", "Natalie's Fire Stick", "the kitchen tablet"). Its address is the device's **Tailscale IP** from `tailscale status` or the Tailscale MCP (`mcp__tailscale__tailscale_list_devices`), never a LAN address: the user's standing rule (`feedback_use_tailscale_ips`). A LAN address is only a temporary fallback when Tailscale is down after a reboot, and you say so when you use it.
- **`keep`** (optional) — apps to keep. Always ask in Step 2 if not given.

## Steps

### 1. Prior art and the right list

1. Read the existing notes first: `reference_tv_debloat_tools_research.md` and `reference_galaxy_tab_a7_debloat_research.md` in the project memory dir. `references/devices.md` has the one-screen summary. A device of the same family as one already done skips the research.
2. For a new device family, run the `research` skill (the lists are days or weeks old and change monthly). Pick the list source per `references/devices.md`: CleanYourTV for Google TV, DumbTV for Fire OS, a Samsung list or UAD-ng for Samsung.
3. Download the candidate list to the scratchpad as one package per line. Retype any `pm` command copied from a web page: pages carry en/em dashes instead of `--`.

### 2. Ask what the device is for

Use **AskUserQuestion**: what the device is used for and which apps stay (streaming apps, Jellyfin, Famdash in Chrome, ...). Write the answers to `$S/keep.txt`. Skip the question only if the user already named them. Do not disable anything the user has not had the chance to protect.

### 3. Connect

Run every adb command through `nix shell nixpkgs#android-tools -c ...` (adb is not installed), from `/tmp` so no stray `.git` is picked up. The user turns on Developer options and debugging on the device, and presses **Allow** on its screen; you cannot do that part.

- **TV / Fire Stick:** `adb connect <tailscale-ip>:5555`.
- **Android 11+ phones and tablets:** wireless debugging uses a random pairing port and a different random connect port, both reset by a reboot (`references/gotchas.md`). If a single pair attempt fails, stop and use USB debugging with a cable: it authorizes immediately.

Confirm with `adb devices -l` and read the model (`getprop ro.product.model`, `ro.build.version.release`). If it shows `unauthorized`, ask the user to press Allow; if `offline`, `adb kill-server` and reconnect.

### 4. Snapshot, then plan

Save to the scratchpad before touching anything: `getprop`, `pm list packages -f`, `pm list packages -d` (what is already disabled), `pm list packages -3` and the HOME activity owner (`cmd package resolve-activity --brief -c android.intent.category.HOME`).

Then build the plan with the script (offline, read-only):

```bash
/home/bosko/NixOS/.claude/skills/android-debloat/scripts/plan-debloat.sh $S/installed.txt $S/candidates.txt $S/keep.txt
```

It tags each candidate `DISABLE` / `KEEP` / `NEVER` / `ABSENT`. `NEVER` comes from `assets/never-disable.txt` and cannot be overridden by a list. Show the user the `DISABLE` set, grouped by purpose, and let them move items to the keep list.

### 5. Apply in small batches

Split `DISABLE` into batches of at most 10 (`MAX_BATCH`), riskiest last. For **each batch**:

1. Show the exact package list and the undo (`pm enable <pkg>`), and confirm with **AskUserQuestion** (Approve / Skip / Change the list).
2. Run `apply-batch.sh` without `--apply` first (a dry run prints the commands), then with `--apply`. Run the script inside the nix shell so `adb` is on its PATH:
   `cd /tmp && nix shell nixpkgs#android-tools -c bash /home/bosko/NixOS/.claude/skills/android-debloat/scripts/apply-batch.sh --apply --log $S/apply.log <tailscale-ip>:5555 $S/batch1.txt`
3. Wait **~20 s after the last disable** (the script runs `sync`), then reboot the device. Rebooting sooner silently reverts the disables.
4. Wait for it to reconnect and finish booting (`getprop sys.boot_completed` = 1), then run `apply-batch.sh --verify`. Any `REVERTED` line means re-apply.
5. Launch the kept apps (`monkey -p <pkg> -c android.intent.category.LAUNCHER 1`) and check each starts; check `logcat -b crash -d | tail` for new crashes. Stop on the first problem and undo that batch.

Handle the launcher and setup wizard on a TV specially: see `references/gotchas.md` (disable the wizard before the stock launcher, rejoin Wi-Fi first). Do not touch the launcher on a Fire Stick or tablet unless the user asks.

### 6. Keep Tailscale reachable

On every device: `cmd deviceidle whitelist +com.tailscale.ipn`, then `settings put secure always_on_vpn_app com.tailscale.ipn` and `settings put secure always_on_vpn_lockdown 0`. Reboot once and check the device returns to the tailnet by itself (`tailscale status`). It worked on the Fire Stick and the tablet. On the TCL TV it cannot start at boot (`TclAppBoot`), so say that plainly: the app has to be opened after each power-on. Never run DumbTV's DNS filter on a device that needs Tailscale: both are a local VPN and Android runs one.

### 7. Finish

1. With the user's go-ahead, turn adb off: `settings put global adb_enabled 0` (and `adb_wifi_enabled 0` where it exists). Port 5555 is unauthenticated plaintext. Say how to turn it back on.
2. Tell the user what to hand-test (remote buttons, Jellyfin playback, the apps they use) and what rollback looks like.
3. Save a `reference_<device>_debloat_*` memory with the `save-memory` skill: device model and Android version, tool and list used, packages disabled, packages deliberately kept, what survived reboots, Tailscale outcome, open items. Add a line to `references/devices.md` if the device taught something new.

## Gotchas

See `references/gotchas.md` — read it before connecting to a Samsung or Android 11+ device and before touching a TV launcher.

## Scripts

- `scripts/plan-debloat.sh INSTALLED CANDIDATES KEEP [NEVER]` — offline plan, tags each candidate.
- `scripts/apply-batch.sh [--apply] TARGET PLAN` / `--verify TARGET PLAN` — dry-run by default; only `pm disable-user`; refuses `NEVER` packages and batches over `MAX_BATCH`.
- `scripts/android-debloat.test.sh` — fixture and stub-adb tests (no device needed).
- `assets/never-disable.txt` — the refuse list; extend it when a device teaches something.
