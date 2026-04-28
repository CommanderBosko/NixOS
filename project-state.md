# NixOS Project State

_Last updated: 2026-04-27_

## Current Project State

The configuration manages four NixOS hosts from a single flake:

| Host | Status | DE |
|------|--------|----|
| `gaming` | Active — Plasma 6 / X11+Wayland | plasma.nix |
| `laptop` | Active — Niri + Dank Material Shell / Wayland | niri.nix |
| `server` | Active — headless | — |
| `vpn-server` | Defined, awaiting deployment | — |

**Security module** is applied to all hosts. AppArmor is enabled with `killUnconfinedConfinables = false` (permissive process handling — won't kill processes missing a confinement profile). The nixpkgs PAM/AppArmor bug workaround is in place and is now correctly gated behind `lib.mkIf config.services.displayManager.sddm.enable` so it only applies on SDDM-enabled desktop hosts.

**VPN module** (`dotfiles/common/modules/vpn.nix`) is applied to gaming and laptop. The VPN server definition (`dotfiles/vpn-server/`) targets an Oracle Cloud free-tier ARM VM (`aarch64-linux`). Public keys in the server peer config are still placeholder strings — they need replacing after keys are generated on the client machines.

**Agent enforcement** is active: `CLAUDE.md` mandates all work be delegated to the `nixos-agent` subagent. The agent definition lives at `.claude/agents/nixos-agent.md`.

## Current Goals

### Short-term (next 1-3 sessions)
- Provision the Oracle Cloud ARM VM and deploy `vpn-server` via `nixos-anywhere`
- Generate WireGuard keypairs on gaming and laptop; replace placeholder public keys in `dotfiles/vpn-server/configuration.nix`
- Verify all four hosts rebuild cleanly after recent flake restructuring (bootloader moved out of `commonModules` into per-host sets)
- Re-evaluate whether to re-enable `killUnconfinedConfinables = true` on the server host once AppArmor profiles are better understood

### Long-term
- Harden the server host further (AppArmor profiles, fail2ban, etc.)
- Potentially add a fifth host or containerised service on the VPN server
- Evaluate moving `qbittorrent` off the package list permanently or replacing it

## Recent Decisions

- **`killUnconfinedConfinables = false`** — Keeps AppArmor MAC enforcement active without the risk of killing legitimate desktop processes that lack profiles. Appropriate for daily-use desktop hosts; can be revisited for the headless server.
- **SDDM PAM workaround now conditional** — `lib.mkIf config.services.displayManager.sddm.enable` ensures the fix only applies where SDDM runs (gaming, laptop), not on the server or vpn-server.
- **Bootloader removed from `commonModules`** — Each host now provides its own bootloader config; server uses GRUB, vpn-server uses systemd-boot (Oracle Cloud EFI).
- **VPN architecture** — WireGuard hub-and-spoke via Oracle Cloud free ARM VM. All client traffic is routed through the server (full-tunnel). IP forwarding + iptables MASQUERADE enabled on the server.
- **`qbittorrent` removed, `nodejs` added** — On both gaming and laptop.
- **Gaming firewall enabled** — `networking.firewall.enable` changed from `false` to `true`.

## Known Issues / Tech Debt

- `vpn-server` peer public keys are placeholders (`GAMING_PUBLIC_KEY`, `LAPTOP_PUBLIC_KEY`). Config will not work until real keys are filled in.
- `dotfiles/laptop/networking.nix` has `PasswordAuthentication = true` — this was intentionally set but should be reverted to `false` once SSH key auth is confirmed working on the laptop.
- The nixpkgs AppArmor/PAM bug may affect other services beyond SDDM if they use PAM include directives; worth auditing if AppArmor is later tightened.
- `dotfiles/vpn-server/configuration.nix` references `enp0s3` as the upstream interface — this may differ on the actual Oracle Cloud instance and will need to be corrected at deploy time.

## Next Steps

1. Provision Oracle Cloud ARM VM; run `nixos-anywhere --flake .#vpn-server`
2. Generate WireGuard keys: `wg genkey | tee /etc/wireguard/private.key | wg pubkey` on gaming and laptop
3. Update peer public keys in `dotfiles/vpn-server/configuration.nix`
4. Configure client-side WireGuard in `dotfiles/common/modules/vpn.nix` (currently empty/stub — check its contents)
5. Test full VPN tunnel from both desktop hosts
6. Revert `PasswordAuthentication` back to `false` in `dotfiles/laptop/networking.nix` once SSH keys are confirmed
