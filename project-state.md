# NixOS Project State

_Last updated: 2026-05-06_

## Current Project State

The configuration manages three active NixOS hosts from a single flake (the `vpn-server` host definition remains but is awaiting deployment):

| Host | Status | DE |
|------|--------|----|
| `gaming` | BROKEN — `nh os switch` fails; blocked by openldap nixpkgs-unstable regression; all config changes are correct and ready to activate | plasma.nix |
| `laptop` | Unknown — not tested recently; last known good; awaiting a successful gaming switch to gain confidence | niri.nix |
| `server` | Active — headless | — |
| `vpn-server` | Defined, awaiting deployment to Oracle Cloud | — |

**Security module is back and fully active in config.** `dotfiles/common/modules/security.nix` was recreated and re-added to `commonModules`. As of 2026-05-06 it is in the flake and will be applied on the next successful `nh os switch`. It includes AppArmor MAC enforcement, auditd, kernel image protection, ASLR, PAM wheel enforcement, and the SDDM PAM override workaround.

**User natty has been removed.** Only `bosko` remains. Home Manager, users.nix, and niri.nix have all been purged of natty references.

**VPN module** (`dotfiles/common/modules/vpn.nix`) is currently commented out in `flake.nix` for both gaming and laptop. Peer public keys are still placeholders.

**Security audit completed 2026-05-06.** All Critical and High findings remediated. Most Medium and Low findings remediated. Three items explicitly deferred (see Known Issues).

## Current Goals

### Short-term (next 1-3 sessions)

- **Unblock the gaming host switch** — monitor nixpkgs-unstable for the openldap regression fix; run `nh os switch /home/bosko/NixOS 2>&1 | tee /tmp/switch.log` and confirm success once it lands
- After a successful switch, confirm the security hardening is active: `aa-status`, `journalctl -u auditd`, verify swaylock triggers on laptop
- M-7/M-8: Generate WireGuard keypairs on gaming and laptop; replace placeholder public keys in `dotfiles/vpn-server/configuration.nix` (and `vpn.nix` client config)
- M-9: Pin server to `nixos-25.05` stable by adding a second nixpkgs input in `flake.nix`
- Confirm `bosko-claude.nix` HM symlinks deploy correctly after first successful switch

### Long-term

- Provision Oracle Cloud ARM VM; deploy `vpn-server` via `nixos-anywhere`
- Re-enable `vpn.nix` on gaming and laptop once VPN server is live and keys are real
- Harden server further with AppArmor profiles and fail2ban once stable channel is pinned
- Evaluate adding a fifth host or containerised service on the VPN server

## Recent Decisions

- **Full security audit remediation (2026-05-06)** — All Critical, High, and most Medium/Low findings addressed in a single session. Rationale: the gaming host is blocked by an unrelated upstream regression anyway; best to get the config into a hardened state before the next activation.
- **natty removed** — No longer needed; was an unnecessary attack surface (wheel group, trusted-user, home directory).
- **security.nix restored** — The module that was removed in April to unblock debugging is back. AppArmor, auditd, kernel hardening, and PAM enforcement are all configured.
- **L-6 declined** — User chose not to change `edit = "sudo hx"` alias to `sudoedit`; alias retained as-is.
- **chrony replaces ntpd** — Applied to all three hosts; handles intermittent connectivity better.
- **WireGuard keys deferred** — Placeholder keys are not a real risk until VPN is deployed; generating them without a live peer adds no security value.
- **Stable nixpkgs pin deferred (M-9)** — Requires adding a second nixpkgs input to flake.nix; scoped to a future session.
- **Claude agents backed up via HM** — `bosko-claude.nix` symlinks agent definitions from the repo into `~/.claude/agents/` on rebuild. Pending first successful switch.
- **nix-ld consolidated into gaming.nix** — All gaming-specific config is colocated in one module.

## Known Issues / Tech Debt

- **Gaming host switch blocked by openldap regression** — `nixpkgs-unstable` has an `openldap-2.6.13-i686-linux` build failure. Dry-run passes; actual switch fails. Blocked on upstream fix.
- **vpn.nix inactive** — Commented out in `flake.nix`. WireGuard client config exists but is not applied to any host.
- **vpn-server peer public keys are placeholders** — `GAMING_PUBLIC_KEY` and `LAPTOP_PUBLIC_KEY` in `dotfiles/vpn-server/configuration.nix` must be replaced with real keys before deployment.
- **M-9 deferred** — Server still runs `nixos-unstable`. Should be pinned to `nixos-25.05` for stability; requires a new flake input.
- **M-7/M-8 deferred** — WireGuard client interface name (`enp0s3`) on vpn-server may not match the Oracle Cloud instance's actual NIC; placeholder keys need replacing.
- **vpn-server references `enp0s3`** — May differ on the actual Oracle Cloud instance; verify at deploy time.
- **bosko-claude.nix HM symlinks** — Pending first successful `nh os switch` to take effect.

## Next Steps

1. **Unblock gaming switch**: monitor nixpkgs-unstable for openldap fix; then run `nh os switch /home/bosko/NixOS 2>&1 | tee /tmp/switch.log`
2. After successful switch: verify security hardening is active (`aa-status`, `journalctl -u auditd`)
3. Generate WireGuard keypairs; replace placeholders in VPN config (M-7/M-8)
4. Add stable nixpkgs input; pin server to `nixos-25.05` (M-9)
5. Provision Oracle Cloud ARM VM; deploy vpn-server via `nixos-anywhere`
6. Re-enable `vpn.nix` on gaming and laptop once VPN server is live
7. Confirm `bosko-claude.nix` HM symlinks deployed correctly
