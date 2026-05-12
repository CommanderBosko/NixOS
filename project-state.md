# NixOS Project State

_Last updated: 2026-05-12_

## Current Project State

The configuration manages four defined NixOS hosts from a single flake (`vpn-server` awaiting deployment; `natalie-laptop` awaiting hardware config and install):

| Host | Status | DE |
|------|--------|----|
| `gaming` | BROKEN — `nh os switch` fails; blocked by openldap nixpkgs-unstable regression; all config is correct and ready to activate once upstream fixes it | plasma.nix |
| `laptop` | **LIVE** — last successful `nh os switch` 2026-05-10; security hardening active; `audit-rules-nixos.service` fix committed 2026-05-11 (not yet re-applied, needs a switch) | niri.nix |
| `server` | Active — headless | — |
| `natalie-laptop` | **Ready to install** — host defined 2026-05-11; real `hardware-configuration.nix` committed 2026-05-12 (Intel CPU, NVMe root, vfat /boot); ready for initial install via `nixos-anywhere` or manual install | cosmic.nix |
| `vpn-server` | Defined, awaiting deployment to Oracle Cloud | — |

**Laptop has an unverified fix pending.** The `audit-rules-nixos.service` was failing during activation because `auditctl` 4.1.2-unstable rejects blank lines in `audit.rules` and nixpkgs hard-codes one. The service is now disabled via `systemd.services.audit-rules-nixos.enable = lib.mkForce false`. This needs to be activated via `nh os switch` to confirm.

**Security module is active.** `dotfiles/common/modules/security.nix` is in `commonModules` and applied on all hosts. It includes AppArmor MAC enforcement, auditd (running; rules-loader disabled), kernel image protection, ASLR, PAM wheel enforcement, SDDM PAM override workaround, and a pin for classic dbus implementation.

**User natty restored (non-elevated).** `natty` is back in `users.nix` and Home Manager with no wheel group or trusted-user privileges. She was removed in the 2026-05-06 security audit for being in the wheel group; restored 2026-05-11 for the Natalie laptop host.

**VPN module deleted.** `dotfiles/common/modules/vpn.nix` was removed on 2026-05-11 — it had been commented out in `flake.nix` since April with no active use. WireGuard VPN remains a goal; the module will be rewritten when deployment is imminent.

**Security audit completed 2026-05-06.** All Critical and High findings remediated. Most Medium and Low findings remediated. Three items explicitly deferred (see Known Issues).

## Current Goals

### Short-term (next 1-3 sessions)

- **Apply the audit-rules-nixos fix on laptop** — run `nh os switch /home/bosko/NixOS` and confirm `auditd` is running while `audit-rules-nixos.service` is inactive/disabled
- **Natalie laptop install** — `hardware-configuration.nix` is now real (committed 2026-05-12); next step is the initial install via `nixos-anywhere` or manual install
- **Unblock the gaming host switch** — monitor nixpkgs-unstable for the openldap regression fix; run `nh os switch /home/bosko/NixOS 2>&1 | tee /tmp/switch.log` once it lands
- After gaming switch succeeds: verify `aa-status`, `journalctl -u auditd`, and confirm `~/.claude/agents/` symlinks are correct
- M-7/M-8: Generate WireGuard keypairs on gaming and laptop; replace placeholder public keys in `dotfiles/vpn-server/configuration.nix`; write the new `vpn.nix` module
- M-9: Pin server to `nixos-25.05` stable by adding a second nixpkgs input in `flake.nix`

### Long-term

- Provision Oracle Cloud ARM VM; deploy `vpn-server` via `nixos-anywhere`
- Write and enable `vpn.nix` on gaming and laptop once VPN server is live and keys are real
- Harden server further with AppArmor profiles and fail2ban once stable channel is pinned
- Evaluate adding a fifth host or containerised service on the VPN server

## Recent Decisions

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

- **Laptop switch needed to apply audit fix** — `systemd.services.audit-rules-nixos.enable = lib.mkForce false` is committed but not yet activated on laptop. Run `nh os switch` to apply.
- **Gaming host switch blocked by openldap regression** — `nixpkgs-unstable` has an `openldap-2.6.13-i686-linux` build failure. Dry-run passes; actual switch fails. Blocked on upstream fix.
- **natalie-laptop install pending** — `hardware-configuration.nix` now contains real hardware data (Intel CPU, NVMe root UUID `d6f891ea-efeb-4d79-97cd-ea6d8966e0ad`, vfat /boot UUID `229A-8574`). Config is complete; host needs its initial install.
- **dbus-broker not yet validated** — Classic dbus is pinned in `security.nix`. dbus-broker cannot be adopted until its AppArmor profile is verified compatible with this config. Safe to revisit once gaming host is switched and AppArmor state is confirmed.
- **vpn.nix does not exist** — Deleted 2026-05-11. WireGuard VPN remains a goal; the module needs to be written from scratch before VPN deployment can proceed.
- **vpn-server peer public keys are placeholders** — `GAMING_PUBLIC_KEY` and `LAPTOP_PUBLIC_KEY` in `dotfiles/vpn-server/configuration.nix` must be replaced with real keys before deployment.
- **M-9 deferred** — Server still runs `nixos-unstable`. Should be pinned to `nixos-25.05` for stability; requires a new flake input.
- **vpn-server references `enp0s3`** — Interface name may differ on the actual Oracle Cloud instance; verify at deploy time.
- **bosko-claude.nix HM symlinks** — Laptop switch succeeded 2026-05-10; confirm `~/.claude/agents/` symlinks are correct. Gaming still pending its switch.

## Next Steps

1. **Apply audit fix on laptop**: run `nh os switch /home/bosko/NixOS`; confirm `auditd` is running and `audit-rules-nixos.service` is disabled; verify swaylock idle trigger still works
2. **Natalie laptop install**: `hardware-configuration.nix` is committed — perform initial install via `nixos-anywhere` or manual install from NixOS ISO
3. **Unblock gaming switch**: monitor nixpkgs-unstable for openldap fix; run `nh os switch /home/bosko/NixOS 2>&1 | tee /tmp/switch.log` once resolved
4. After gaming switch succeeds: verify `aa-status`, `journalctl -u auditd`; confirm `~/.claude/agents/` symlinks are correct
5. Generate WireGuard keypairs on gaming and laptop; write the new `vpn.nix` module; replace placeholders in `dotfiles/vpn-server/configuration.nix` (M-7/M-8)
6. Add stable nixpkgs input; pin server to `nixos-25.05` (M-9)
7. Provision Oracle Cloud ARM VM; deploy vpn-server via `nixos-anywhere`
8. Enable VPN on gaming and laptop once server is live and keys are real
