---
name: nix-flatpak-unpinned-nixpkgs
description: nix-flatpak does not follow our nixpkgs input and silently injects older NixOS module defaults (e.g. dbus implementation = "dbus") that override upstream changes
type: feedback
---

`nix-flatpak` in `flake.nix` has no `inputs.nixpkgs.follows = "nixpkgs"`. It brings its own pinned nixpkgs (rev `da5ad661`) whose NixOS modules may have different defaults than the nixpkgs we're actually targeting.

**Why:** Discovered 2026-05-21 while debugging why natalie-laptop stayed on dbus-daemon despite nixpkgs-unstable having defaulted to dbus-broker. The nix-flatpak nixpkgs's `dbus.nix` with `default = "dbus"` was silently winning in the NixOS module merge priority for `mkDefault` values.

**How to apply:** Whenever nixpkgs adds a new `mkDefault` for a service option and we expect it to take effect on desktop hosts, verify with `nix eval .#nixosConfigurations.<host>.config.<option>`. If it doesn't match, check whether nix-flatpak's unpinned nixpkgs is providing a conflicting default. The fix is to set the option explicitly (not with `mkDefault`) in `security.nix` or another shared module — this beats all `mkDefault` values regardless of their source. Do NOT rely on nixpkgs upstream defaults taking effect passively when nix-flatpak is in the module chain.

Related: [[dbus-broker default change in nixpkgs unstable]]
