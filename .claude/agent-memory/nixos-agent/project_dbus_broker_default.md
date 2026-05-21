---
name: dbus-broker default change in nixpkgs unstable
description: nixpkgs-unstable changed services.dbus.implementation default from "dbus" to "broker" around 2026-04-14 (rev 4bd9165). This triggers the nh os switch inhibitor and causes boot failure if applied incorrectly.
type: project
---

The locked nixpkgs revision `4bd9165` (lastModified 2026-04-14, 26.05 pre-release) changed `services.dbus.implementation` default from `"dbus"` to `"broker"` in `nixos/modules/services/system/dbus.nix`.

**Why:** nixpkgs upstream is moving to dbus-broker as the default implementation. This is a critical service transition — systemd units change (dbus.service → dbus-broker.service), which is why `nh os switch` fires its `switchInhibitors` check and refuses to apply the change live.

**How to apply:** Never apply via `nh os switch` / `nixos-rebuild switch` alone. Must use `nixos-rebuild boot` + reboot. But if the new config has issues (e.g., AppArmor profile for dbus-broker not loading, or sddm PAM interaction), the VM won't boot. The fix is:

1. Boot into previous generation from GRUB (hold Shift at boot, select NixOS generations, pick the second entry)
2. Either pin back to classic dbus with `services.dbus.implementation = "dbus";` in a shared module, or diagnose the broker boot failure
3. If intentionally accepting broker: test on a host that has a console fallback first

The config in this repo does NOT explicitly set `services.dbus.implementation` anywhere — it was purely a nixpkgs default change that was pulled in by the flake lock bump in commit 629afc2 (2026-04-28).

The `services.dbus.apparmor = "enabled"` in `security.nix` is orthogonal — it configures the AppArmor mediation mode within whichever dbus implementation is running. It does NOT force broker. The actual trigger was the nixpkgs default change.

## Rollout Status (as of 2026-05-21) — COMPLETE

| Host | Status | Notes |
|------|--------|-------|
| vpn-server | COMPLETE | Verified first; headless, no DE risk |
| gaming | COMPLETE | Verified 2026-05-21: dbus-broker active, 0 failed units, Plasma/PipeWire/WirePlumber all healthy |
| laptop | COMPLETE | Verified 2026-05-21: system + user broker both active, 0 failed units, pipewire masked (expected on Niri) |
| natalie-laptop | STAGED | `nh os boot` staged; pending user reboot to activate |

**Cleanup done:** All per-host `services.dbus.implementation = lib.mkForce "broker"` overrides removed from gaming/environment.nix, server/environment.nix, and vpn-server/configuration.nix. The holdback `lib.mkDefault "dbus"` was already removed from security.nix. nixpkgs unstable now defaults to broker; no explicit setting needed anywhere.

**Known-benign warnings in dbus-broker journal:**
- `Ignoring duplicate name '...'` — dbus-broker is stricter than reference dbus about duplicate service file entries in the Nix store. Harmless.
- `Invalid group-name 'netdev'` in avahi-dbus.conf — netdev group not defined on this host; avahi still functions.
- `Invalid user-name 'systemd-timesync'` in timesync1.conf — dynamic user not present in NSS at parse time; timesyncd still works.
- `Activation request for 'org.freedesktop.resolve1' failed` — systemd-resolved not enabled on gaming; expected.
