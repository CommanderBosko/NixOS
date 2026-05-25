---
name: nix-flatpak-unpinned-nixpkgs
description: nix-flatpak does NOT bundle its own nixpkgs (flake declares zero inputs); the dbus-broker resistance was from module evaluation order, not a bundled nixpkgs
type: feedback
---

`nix-flatpak` declares zero inputs in its `flake.nix` — it does not bundle its own nixpkgs at all. The earlier belief that it bundled rev `da5ad661` was a misdiagnosis.

**Why:** Investigated 2026-05-25. The original "bundled nixpkgs" theory was formed while debugging why dbus-broker resistance persisted on desktop hosts. The real cause was NixOS module evaluation order (nix-flatpak's module providing `mkDefault "dbus"` coming from its evaluated module file), not a pinned nixpkgs shadow.

**How to apply:** Do not add `inputs.nixpkgs.follows = "nixpkgs"` to nix-flatpak in flake.nix — it has no nixpkgs input to override. The correct and still-valid fix when a nix-flatpak module default conflicts with our desired setting is to assign the option explicitly (no `mkDefault`) in `security.nix` or another shared module, which beats all `mkDefault` values regardless of source. Never rely on nixpkgs upstream `mkDefault` values taking effect passively when nix-flatpak is in the module chain.

Related: [[dbus-broker default change in nixpkgs unstable]]
