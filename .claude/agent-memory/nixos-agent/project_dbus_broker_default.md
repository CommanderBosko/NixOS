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
