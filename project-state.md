# NixOS Project State

_Last updated: 2026-05-03_

## Current Project State

The configuration manages four NixOS hosts from a single flake:

| Host | Status | DE |
|------|--------|----|
| `gaming` | BROKEN — `nh os switch` fails; dry-run passes; blocked by openldap nixpkgs regression | plasma.nix |
| `laptop` | Unknown — not tested recently | niri.nix |
| `server` | Active — headless | — |
| `vpn-server` | Defined, awaiting deployment | — |

**Security module has been removed.** `dotfiles/common/modules/security.nix` was deleted and de-referenced from `commonModules` in `flake.nix`. No security hardening (AppArmor, audit, kernel params, PAM wheel enforcement) is currently applied to any host. Temporary regression — will be reintroduced incrementally once the base switch is stable.

**VPN module** (`dotfiles/common/modules/vpn.nix`) is currently commented out in `flake.nix` for both gaming and laptop. The `vpn-server` configuration remains in the flake and is untouched. Peer public keys are still placeholders.

**Claude agents** are now backed up declaratively via Home Manager. `bosko-claude.nix` symlinks `repo-creator-agent.md` and `session-closer.md` from the repo into `~/.claude/agents/` on every rebuild.

**gaming.nix** now contains all gaming-specific system config: Steam, GameMode, Gamescope, MangoHud, nix-ld (with full library list), and `hardware.steam-hardware`. The `nix-ld` block has been removed from `dotfiles/gaming/environment.nix`.

**Agent enforcement** is active: `CLAUDE.md` mandates all work be delegated to the `nixos-agent` subagent. The agent definition lives at `dotfiles/common/configs/claude/agents/session-closer.md` and `repo-creator-agent.md`.

## Current Goals

### Short-term (next 1-3 sessions)
- **Unblock the gaming host switch** — monitor nixpkgs-unstable for the openldap regression fix; once merged, run `nh os switch /home/bosko/NixOS 2>&1 | tee /tmp/switch.log` and confirm success
- Re-introduce security hardening incrementally once the switch is stable: start with AppArmor only, test, then add audit daemon and kernel hardening
- Re-enable `vpn.nix` on gaming and laptop after the base switch is confirmed working
- Provision the Oracle Cloud ARM VM and deploy `vpn-server` via `nixos-anywhere`
- Generate WireGuard keypairs on gaming and laptop; replace placeholder public keys in `dotfiles/vpn-server/configuration.nix`

### Long-term
- Harden the server host further (AppArmor profiles, fail2ban, etc.)
- Potentially add a fifth host or containerised service on the VPN server
- Evaluate moving `qbittorrent` off the package list permanently or replacing it

## Recent Decisions

- **Claude agents backed up via HM** — `bosko-claude.nix` symlinks agent definitions from the repo into `~/.claude/agents/`. Switch is pending the openldap regression fix.
- **nix-ld consolidated into gaming.nix** — All gaming-specific config (Steam, GameMode, Gamescope, nix-ld, steam-hardware) now lives in one module. `gaming/environment.nix` is cleaner.
- **security.nix removed temporarily** — The module was blocking the gaming host rebuild. Will be reintroduced incrementally once the base switch succeeds.
- **vpn.nix commented out** — Precautionary measure while the switch issue is diagnosed.
- **Flake inputs bumped** (multiple sessions) — DankMaterialShell, home-manager, nixpkgs, and quickshell updated to latest revisions.
- **`killUnconfinedConfinables = false`** — Was set before security.nix was removed; will be kept when the module is reintroduced.
- **Bootloader removed from `commonModules`** — Each host provides its own bootloader; server uses GRUB, vpn-server uses systemd-boot.
- **VPN architecture** — WireGuard hub-and-spoke via Oracle Cloud free ARM VM. Full-tunnel routing. IP forwarding + iptables MASQUERADE on server.
- **`qbittorrent` removed, `nodejs` added** — On both gaming and laptop.
- **Gaming firewall enabled** — `networking.firewall.enable` changed from `false` to `true`.

## Known Issues / Tech Debt

- **Gaming host switch blocked by openldap regression** — `nixpkgs-unstable` has a regression preventing the gaming host switch from completing. Dry-run passes. Blocked on upstream fix in nixpkgs.
- **No security hardening on any host** — `security.nix` was deleted. AppArmor, audit daemon, kernel image protection, ASLR enforcement, and PAM wheel enforcement are all inactive. Deliberate temporary state.
- **vpn.nix inactive** — Commented out in `flake.nix`. WireGuard client config exists but is not applied.
- `vpn-server` peer public keys are placeholders (`GAMING_PUBLIC_KEY`, `LAPTOP_PUBLIC_KEY`).
- `dotfiles/laptop/networking.nix` has `PasswordAuthentication = true` — revert to `false` once SSH key auth is confirmed.
- `dotfiles/vpn-server/configuration.nix` references `enp0s3` as the upstream interface — may differ on the actual Oracle Cloud instance.
- `bosko-claude.nix` HM symlinks pending first successful switch after openldap regression is resolved.

## Next Steps

1. **Unblock gaming switch**: monitor nixpkgs-unstable for openldap regression fix; then run `nh os switch /home/bosko/NixOS 2>&1 | tee /tmp/switch.log`
2. Confirm `bosko-claude.nix` HM symlinks deploy correctly after the first successful switch
3. Re-introduce security hardening incrementally (AppArmor only first, then audit + kernel params)
4. Re-enable `vpn.nix` on gaming and laptop once switch is stable
5. Provision Oracle Cloud ARM VM; run `nixos-anywhere --flake .#vpn-server`
6. Generate WireGuard keys and replace placeholders in `dotfiles/vpn-server/configuration.nix`
7. Revert `PasswordAuthentication = true` in `dotfiles/laptop/networking.nix`
