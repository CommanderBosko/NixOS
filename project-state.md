# NixOS Project State

_Last updated: 2026-04-28_

## Current Project State

The configuration manages four NixOS hosts from a single flake:

| Host | Status | DE |
|------|--------|----|
| `gaming` | BROKEN — `nh os switch` fails; dry-run passes | plasma.nix |
| `laptop` | Unknown — not tested this session | niri.nix |
| `server` | Active — headless | — |
| `vpn-server` | Defined, awaiting deployment | — |

**Security module has been removed.** `dotfiles/common/modules/security.nix` was deleted and de-referenced from `commonModules` in `flake.nix`. It was causing the gaming host switch to fail. No security hardening (AppArmor, audit, kernel params, PAM wheel enforcement) is currently applied to any host. This is a temporary regression — hardening should be reintroduced incrementally once the base switch is stable.

**VPN module** (`dotfiles/common/modules/vpn.nix`) is currently commented out in `flake.nix` for both gaming and laptop. The `vpn-server` configuration remains in the flake and is untouched. Peer public keys are still placeholders.

**Agent enforcement** is active: `CLAUDE.md` mandates all work be delegated to the `nixos-agent` subagent. The agent definition lives at `.claude/agents/nixos-agent.md`.

## Current Goals

### Short-term (next 1-3 sessions)
- **Diagnose and fix the gaming host switch failure** — run `nh os switch` with captured output; the dry-run passes (24 derivations) but the actual switch fails at an unknown point
- Re-introduce security hardening incrementally once the switch is stable: start with AppArmor only, test, then add audit daemon and kernel hardening
- Re-enable `vpn.nix` on gaming and laptop after the base switch is confirmed working
- Provision the Oracle Cloud ARM VM and deploy `vpn-server` via `nixos-anywhere`
- Generate WireGuard keypairs on gaming and laptop; replace placeholder public keys in `dotfiles/vpn-server/configuration.nix`

### Long-term
- Harden the server host further (AppArmor profiles, fail2ban, etc.)
- Potentially add a fifth host or containerised service on the VPN server
- Evaluate moving `qbittorrent` off the package list permanently or replacing it

## Recent Decisions

- **security.nix removed temporarily** — The module was blocking the gaming host rebuild. Rather than debug AppArmor/PAM interactions blind, the module was stripped out entirely so the host can be returned to a working state. Security hardening will be reintroduced incrementally.
- **vpn.nix commented out** — Precautionary measure while the switch issue is diagnosed. Keeps the VPN config in the repo without activating it.
- **Flake inputs bumped** — DankMaterialShell, home-manager, nixpkgs, and quickshell all updated to latest revisions.
- **`killUnconfinedConfinables = false`** (prior session) — Was set before security.nix was removed; will be kept when the module is reintroduced.
- **Bootloader removed from `commonModules`** — Each host provides its own bootloader; server uses GRUB, vpn-server uses systemd-boot.
- **VPN architecture** — WireGuard hub-and-spoke via Oracle Cloud free ARM VM. Full-tunnel routing. IP forwarding + iptables MASQUERADE on server.
- **`qbittorrent` removed, `nodejs` added** — On both gaming and laptop.
- **Gaming firewall enabled** — `networking.firewall.enable` changed from `false` to `true`.

## Known Issues / Tech Debt

- **Gaming host switch is broken** — `nh os switch` fails with an uncaptured error. Dry-run passes (24 derivations). Root cause unknown; likely a service activation or build failure introduced before security.nix was removed, or caused by the flake input bump.
- **No security hardening on any host** — `security.nix` was deleted. AppArmor, audit daemon, kernel image protection, ASLR enforcement, and PAM wheel enforcement are all inactive. This is a deliberate temporary state.
- **vpn.nix inactive** — Commented out in `flake.nix`. WireGuard client config exists but is not applied.
- `vpn-server` peer public keys are placeholders (`GAMING_PUBLIC_KEY`, `LAPTOP_PUBLIC_KEY`).
- `dotfiles/laptop/networking.nix` has `PasswordAuthentication = true` — should be reverted to `false` once SSH key auth is confirmed.
- `dotfiles/vpn-server/configuration.nix` references `enp0s3` as the upstream interface — may differ on the actual Oracle Cloud instance.

## Next Steps

1. **Diagnose gaming switch failure**: run `nh os switch /home/bosko/NixOS 2>&1 | tee /tmp/switch.log` and read the output
2. Fix whatever is causing the switch to fail
3. Re-introduce security hardening incrementally (AppArmor only first, then audit + kernel params)
4. Re-enable `vpn.nix` on gaming and laptop once switch is stable
5. Provision Oracle Cloud ARM VM; run `nixos-anywhere --flake .#vpn-server`
6. Generate WireGuard keys and replace placeholders in `dotfiles/vpn-server/configuration.nix`
7. Revert `PasswordAuthentication = true` in `dotfiles/laptop/networking.nix`
