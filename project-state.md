# NixOS Project State

_Last updated: 2026-05-14_

## Current Project State

The configuration manages five defined NixOS hosts from a single flake (`vpn-server` awaiting deployment):

| Host | Status | DE |
|------|--------|----|
| `gaming` | **LIVE** — up to date as of 2026-05-14; all session changes applied. AMD card swap in preparation: `nvidia.nix` now per-host so it can be dropped independently. | plasma.nix |
| `laptop` | **LIVE** — up to date as of 2026-05-14; `audit-rules-nixos.service` fix active. | niri.nix |
| `server` | Active — headless | — |
| `natalie-laptop` | **LIVE** — installed and running; Cosmic DE verified. | cosmic.nix |
| `vpn-server` | Defined, awaiting deployment to Oracle Cloud (`aarch64-linux`) | — |

**`rebuild` alias now uses `nh os boot`.** As of 2026-05-12, the `rebuild` shell alias stages changes for the next reboot rather than attempting a live switch.

**AMD card swap preparation in progress.** `nvidia.nix` was removed from `desktopModules` on 2026-05-14 and is now listed explicitly per-host. When the physical NVIDIA card is replaced with AMD on gaming, removing `nvidia.nix` from gaming's module list in `flake.nix` is the only change needed.

**Home Manager reorganised.** `home-manager.nix` was refactored into a single nested `home-manager { }` block; `stateVersion` was moved here from `home.nix`; natty's block now correctly imports `home.nix` (previously missing).

**`claude-code` and `gemini-cli` moved to user-level packages.** Both tools are now declared in `users.users.bosko.packages` in `users.nix` rather than repeated per-host in `environment.nix`.

**Security module is active.** `dotfiles/common/modules/security.nix` is in `commonModules` and applied on all hosts. Includes AppArmor MAC enforcement, auditd (running; rules-loader disabled), kernel image protection, ASLR, PAM wheel enforcement, SDDM PAM override workaround, and a pin for classic dbus.

**Security audit completed 2026-05-06.** All Critical and High findings remediated. Most Medium and Low findings remediated. Three items explicitly deferred (see Known Issues).

## Current Goals

### Short-term (next 1-3 sessions)

- **AMD card swap on gaming** — when the physical card is swapped, remove `nvidia.nix` from gaming's module list in `flake.nix`; run `rebuild` and reboot
- **Re-enable lutris on gaming** — once nixpkgs-unstable ships a binary cache entry for `openldap-2.6.13-i686-linux`, uncomment `lutris` in `gaming.nix`
- **Validate dbus-broker** — classic dbus is pinned in `security.nix`; once AppArmor profile compatibility is confirmed on the current config, dbus-broker can be re-enabled
- M-7/M-8: Generate WireGuard keypairs on gaming and laptop; replace placeholder public keys in `dotfiles/vpn-server/configuration.nix`; write the new `vpn.nix` module
- M-9: Pin server to `nixos-25.05` stable by adding a second nixpkgs input in `flake.nix`

### Long-term

- Provision Oracle Cloud ARM VM; deploy `vpn-server` via `nixos-anywhere`
- Write and enable `vpn.nix` on gaming and laptop once VPN server is live and keys are real
- Harden server further with AppArmor profiles and fail2ban once stable channel is pinned
- Evaluate adding a fifth host or containerised service on the VPN server

## Recent Decisions

- **`nvidia.nix` scoped per-host (2026-05-14)** — Removed from `desktopModules`; each desktop host (gaming, laptop, natalie-laptop) now imports it explicitly. Preparation for the gaming AMD card swap: dropping NVIDIA from gaming will require only a one-line flake change.
- **`rebuild` alias switched to `nh os boot` (2026-05-12)** — Avoids live-switch activation failures. Changes are staged; rebooting applies them.
- **`claude-code` and `gemini-cli` moved to `users.nix` user packages (2026-05-14)** — User-scoped tools belong in `users.users.bosko.packages`, not duplicated across per-host `environment.nix` files.
- **Cleanup retention reduced to 3 builds (2026-05-14)** — 3 generations is sufficient rollback headroom; saves disk space.
- **natty now gets `home.nix` applied (2026-05-14)** — The `home-manager.nix` reorganisation added the missing `home.nix` import to natty's HM block. Previously natty had a HM block with no imports.
- **`lutris` commented out in gaming.nix (2026-05-12)** — `lutris` transitively depends on `openldap-2.6.13` for `i686-linux`; that derivation has no binary cache entry and attempting to build it from source blocks `nh os switch` for hours. Workaround: `# lutris` comment in `gaming.nix`; `faugus-launcher` (already in the list) covers the use-case. Restore once a binary cache entry exists.
- **`audit-rules-nixos.service` disabled (2026-05-11)** — `auditctl` 4.1.2-unstable rejects blank lines in `audit.rules`; nixpkgs hard-codes one before `-e 1`. Disabling the service via `systemd.services.audit-rules-nixos.enable = lib.mkForce false` is cleaner than patching nixpkgs. `auditd` continues running (required for AppArmor). If custom audit rules are needed in future, load them via a separate unit.
- **`natty` restored as non-wheel user (2026-05-11)** — Removed in the 2026-05-06 audit for being in the wheel group. Now back with no elevated privileges (no wheel, no trusted-user) for the Natalie laptop host.
- **`vpn.nix` deleted (2026-05-11)** — File had been commented out in `flake.nix` since April; deleted to reduce dead code. Will be rewritten from scratch when VPN deployment is imminent.
- **`amd.nix` scoped to gaming host only (2026-05-11)** — The laptop has no AMD GPU; `amd.nix` was incorrectly in `desktopModules`. Now imported only in the gaming host's module list.
- **dbus pinned to classic implementation (2026-05-10)** — nixpkgs-unstable rev `4bd9165` silently changed `services.dbus.implementation` default to `"broker"`. Fix: `services.dbus.implementation = lib.mkDefault "dbus";` in `security.nix`. Broker should not be re-enabled until validated against this AppArmor configuration.
- **Full security audit remediation (2026-05-06)** — All Critical, High, and most Medium/Low findings addressed in a single session. Rationale: the gaming host is blocked by an unrelated upstream regression anyway; best to get the config into a hardened state before the next activation.
- **L-6 declined** — User chose not to change `edit = "sudo hx"` alias to `sudoedit`; alias retained as-is.
- **chrony replaces ntpd** — Applied to all three hosts; handles intermittent connectivity better.
- **WireGuard keys deferred** — Placeholder keys are not a real risk until VPN is deployed; generating them without a live peer adds no security value.
- **Stable nixpkgs pin deferred (M-9)** — Requires adding a second nixpkgs input to flake.nix; scoped to a future session.
- **Claude agents backed up via HM** — `bosko-claude.nix` symlinks agent definitions from the repo into `~/.claude/agents/` on rebuild. Confirmed on laptop (switch succeeded 2026-05-10); gaming pending its switch.
- **nix-ld consolidated into gaming.nix** — All gaming-specific config is colocated in one module.

## Known Issues / Tech Debt

- **lutris disabled on gaming (upstream openldap regression)** — `openldap-2.6.13-i686-linux` has no binary cache entry in nixpkgs-unstable; `lutris` was commented out as a workaround. Re-enable once a cache entry appears. `faugus-launcher` covers the immediate need.
- **dbus-broker not yet validated** — Classic dbus is pinned in `security.nix`. dbus-broker cannot be adopted until its AppArmor profile is verified compatible with this config.
- **vpn.nix does not exist** — Deleted 2026-05-11. WireGuard VPN remains a goal; the module needs to be written from scratch before VPN deployment can proceed.
- **vpn-server peer public keys are placeholders** — `GAMING_PUBLIC_KEY` and `LAPTOP_PUBLIC_KEY` in `dotfiles/vpn-server/configuration.nix` must be replaced with real keys before deployment.
- **M-9 deferred** — Server still runs `nixos-unstable`. Should be pinned to `nixos-25.05` for stability; requires a new flake input.
- **vpn-server references `enp0s3`** — Interface name may differ on the actual Oracle Cloud instance; verify at deploy time.

## Next Steps

1. **AMD card swap on gaming**: when the physical card arrives, remove `nvidia.nix` from gaming's module list in `flake.nix`; run `rebuild` and reboot; verify `amd.nix` is sufficient
2. **Re-enable lutris when possible**: monitor nixpkgs-unstable for `openldap-2.6.13-i686-linux` binary cache entry; remove the comment-out from `gaming.nix`
3. **Validate dbus-broker**: test dbus-broker AppArmor compatibility on the current config; if clean, remove the `lib.mkDefault "dbus"` pin from `security.nix`
4. Generate WireGuard keypairs on gaming and laptop; write the new `vpn.nix` module; replace placeholders in `dotfiles/vpn-server/configuration.nix` (M-7/M-8)
5. Add stable nixpkgs input; pin server to `nixos-25.05` (M-9)
6. Provision Oracle Cloud ARM VM; deploy vpn-server via `nixos-anywhere`
7. Enable VPN on gaming and laptop once server is live and keys are real
