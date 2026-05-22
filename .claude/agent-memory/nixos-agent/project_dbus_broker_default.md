---
name: dbus-broker default change in nixpkgs unstable
description: nixpkgs-unstable changed services.dbus.implementation default to "broker". Root cause of natalie-laptop lag: nix-flatpak's unpinned nixpkgs silently overrode the new default. Fixed by explicit setting in security.nix.
type: project
---

The locked nixpkgs revision `4bd9165` (lastModified 2026-04-14) changed `services.dbus.implementation` default from `"dbus"` to `"broker"` in `nixos/modules/services/system/dbus.nix`.

**Why:** nixpkgs upstream is moving to dbus-broker as the default. This is a critical service transition — systemd units change (dbus.service → dbus-broker.service), which fires `nh os switch`'s `switchInhibitors` check and refuses to apply the change live. Must use `nh os boot` + reboot.

**How to apply:** Never apply via `nh os switch` / `nixos-rebuild switch` alone. Must use `nh os boot` + reboot.

## Root cause of natalie-laptop broker resistance (discovered 2026-05-21)

`nix-flatpak` in `flake.nix` has **no** `inputs.nixpkgs.follows = "nixpkgs"`. It brings its own older nixpkgs (rev `da5ad661`, `lastModified: 1767983141`) whose `dbus.nix` still defaults to `"dbus"`. During module merging, this older `mkDefault "dbus"` was silently winning over the newer nixpkgs `mkDefault "broker"`, keeping dbus-daemon on all desktop hosts regardless of how many times they rebooted.

**Fix applied (2026-05-21):** Added `services.dbus.implementation = "broker";` to `/home/bosko/NixOS/dotfiles/common/modules/security.nix`. This is an explicit (non-default) assignment — it beats any `mkDefault` from any flake input's nixpkgs regardless of version. All five hosts now evaluate to `"broker"`.

This also revealed that the `services.dbus.implementation = lib.mkDefault "dbus"` holdback removed in commit 4370472 was unnecessary — the nix-flatpak input's older nixpkgs was providing that same holdback passively. Removing it didn't fix natalie-laptop because the nix-flatpak default was still in play.

**Known-benign warnings in dbus-broker journal:**
- `Ignoring duplicate name '...'` — dbus-broker is stricter about duplicate service file entries in the Nix store. Harmless.
- `Invalid group-name 'netdev'` in avahi-dbus.conf — netdev group not defined on this host; avahi still functions.
- `Invalid user-name 'systemd-timesync'` in timesync1.conf — dynamic user not present in NSS at parse time; timesyncd still works.
- `Activation request for 'org.freedesktop.resolve1' failed` — systemd-resolved not enabled on gaming; expected.

## Rollout Status — COMPLETE on all 5 hosts (verified 2026-05-21)

| Host | Status | Notes |
|------|--------|-------|
| vpn-server | COMPLETE | Verified; headless, no DE risk |
| gaming | COMPLETE | Verified 2026-05-21: dbus-broker active, 0 failed units |
| laptop | COMPLETE | Verified 2026-05-21: system + user broker both active, 0 failed units |
| server | COMPLETE | On nixpkgs-stable 25.05; explicit setting applies; headless |
| natalie-laptop | COMPLETE | Verified 2026-05-21 after git pull + nh os boot + reboot: system broker active (ExecStart=dbus-broker-launch), user broker active, 0 failed units, cosmic-greeter-daemon active. Git HEAD: 7ce37e1. |

**Root cause summary:** `nix-flatpak` bundles its own unpinned nixpkgs (rev `da5ad661`) whose `dbus.nix` still has `mkDefault "dbus"`. This silently outcompeted the newer nixpkgs `mkDefault "broker"` during module merge. Fixed by a plain (non-default) `services.dbus.implementation = "broker"` assignment in `security.nix`, which beats any `mkDefault` regardless of source.

**Fix confirmed correct on all hosts:** Plain assignment in `dotfiles/common/modules/security.nix` is the definitive fix. All five hosts verified running `dbus-broker-launch`.
